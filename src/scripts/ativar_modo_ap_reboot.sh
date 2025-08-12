#!/bin/bash

LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"
exec >> "$LOG_FILE" 2>&1

# Apaga GPIO27 (pino físico 13)
GPIO27=27
if [ ! -d /sys/class/gpio/gpio$GPIO27 ]; then
  echo $GPIO27 > /sys/class/gpio/export
  sleep 1
fi
echo out > /sys/class/gpio/gpio$GPIO27/direction
echo 0 > /sys/class/gpio/gpio$GPIO27/value

# Configura GPIO22 (pino físico 15) para LED piscando
LED_GPIO=22  # pino físico 15 (GPIO22)

echo "[INFO] --- Iniciando modo Access Point ---"

if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
  echo $LED_GPIO > /sys/class/gpio/export
  sleep 1
fi
echo out > /sys/class/gpio/gpio$LED_GPIO/direction

(
  while true; do
    echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
    sleep 0.5
    echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
    sleep 0.5
  done
) &
LED_PID=$!

echo "[INFO] Desconectando Wi-Fi atual e limpando configurações..."

echo "[INFO] Limpando redes Wi-Fi salvas..."
sudo bash -c 'echo -e "# wpa_supplicant.conf limpo para modo AP\n" > /etc/wpa_supplicant/wpa_supplicant.conf'

sudo systemctl stop wpa_supplicant

sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -f /etc/dnsmasq.conf

echo "[INFO] Criando arquivo hostapd.conf..."
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

echo "[INFO] Criando arquivo dnsmasq.conf..."
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
dhcp-range=192.168.0.50,192.168.0.150,12h
EOF

echo "[INFO] Configurando IP fixo para wlan0..."
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf

sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF
interface wlan0
static ip_address=192.168.0.1/24
nohook wpa_supplicant
EOF

echo "[INFO] Reiniciando serviços..."
sudo systemctl restart dhcpcd
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq

echo "[SUCESSO] Modo Access Point configurado com sucesso. Reiniciando em 5 segundos..."
sleep 5

kill $LED_PID
echo 0 > /sys/class/gpio/gpio$LED_GPIO/value

sudo reboot