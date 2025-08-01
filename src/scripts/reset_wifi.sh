#!/bin/bash

echo "Desconectando Wi-Fi atual e configurando modo Access Point..."

# Remove configurações antigas do AP, caso existam
sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -f /etc/dnsmasq.conf

# Configura hostapd para rodar com wlan0
sudo tee /etc/default/hostapd > /dev/null <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

# Cria arquivo hostapd.conf (modifique SSID e senha abaixo conforme quiser)
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211
ssid=RaspberryPi-AP
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=raspberry
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

# Configura dnsmasq (DHCP server)
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
dhcp-range=192.168.0.50,192.168.0.150,12h
EOF

# Configura IP fixo para wlan0
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf # Remove linhas antigas
sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF
interface wlan0
static ip_address=192.168.0.1/24
nohook wpa_supplicant
EOF

# Recarrega dhcpcd e ativa serviços
sudo systemctl restart dhcpcd
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq

echo "Modo Access Point configurado. Reiniciando em 5 segundos..."
sleep 5
sudo reboot

# Antes de usar o script, instale e habilite os pacotes necessários:
# sudo apt update
# sudo apt install -y hostapd dnsmasq
# sudo systemctl stop hostapd
# sudo systemctl stop dnsmasq

# Como usar
# Salve esse script como /home/pi/reset_wifi.sh

# Torne executável: chmod +x /home/pi/reset_wifi.sh

# Execute com sudo /home/pi/reset_wifi.sh

# O que acontece:
# O Pi apaga a configuração Wi-Fi atual para "esquecer" redes.

# Configura um IP fixo estático na wlan0: 192.168.4.1.

# Configura o Pi como Access Point com SSID RaspberryPi-AP e senha raspberry.

# Configura DHCP para clientes conectados no AP.

# Reinicia o Pi para aplicar tudo.

# Você conecta seu computador/celular nessa rede Wi-Fi do Pi e acessa o IP fixo 192.168.4.1.