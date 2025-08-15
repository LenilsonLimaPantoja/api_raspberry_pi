#!/bin/bash
# Define que o interpretador do script será o bash. Todos os comandos serão executados pelo shell bash.

# GPIO27 (pino físico 13)
GPIO27=27

if [ ! -d /sys/class/gpio/gpio$GPIO27 ]; then
  echo $GPIO27 > /sys/class/gpio/export
  sleep 1
fi

echo out > /sys/class/gpio/gpio$GPIO27/direction
echo 0 > /sys/class/gpio/gpio$GPIO27/value

# CONFIGURAÇÃO DO LED INDICADOR (GPIO22, pino físico 15)
LED_GPIO=22

if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
  echo $LED_GPIO > /sys/class/gpio/export
  sleep 1
fi

echo out > /sys/class/gpio/gpio$LED_GPIO/direction

# Loop em background que pisca o LED enquanto o AP está sendo configurado
(
  while true; do
    echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
    sleep 0.5
    echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
    sleep 0.5
  done
) &
LED_PID=$!

# LIMPA A CONFIGURAÇÃO WIFI
echo "Desconectando Wi-Fi e limpando configurações."
echo "Limpando redes Wi-Fi salvas."
sudo bash -c 'echo -e "# wpa_supplicant.conf limpo para modo AP\n" > /etc/wpa_supplicant/wpa_supplicant.conf'

sudo systemctl stop wpa_supplicant

sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -f /etc/dnsmasq.conf

# CONFIGURAÇÃO DO HOSTAPD (Access Point)
echo "Criando arquivo hostapd.conf."
sudo tee /etc/default/hostapd > /dev/null <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211
ssid=Balanca-AP
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=12345678
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

# CONFIGURAÇÃO DO DNSMASQ (DHCP)
echo "Criando arquivo dnsmasq.conf."
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
dhcp-range=192.168.0.50,192.168.0.150,12h
EOF

# CONFIGURAÇÃO DE IP FIXO PARA WLAN0
echo "Configurando IP fixo para wlan0."
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf

sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF
interface wlan0
static ip_address=192.168.0.1/24
nohook wpa_supplicant
EOF

# SERVIÇOS DE REDE
echo "Serviços de rede."
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

# FINALIZAÇÃO
echo "Modo Access Point configurado. Reiniciando em 1 segundo."
sleep 1

kill $LED_PID
echo 0 > /sys/class/gpio/gpio$LED_GPIO/value

sudo reboot