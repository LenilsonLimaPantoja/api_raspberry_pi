#!/bin/bash

# Ativa modo cliente Wi-Fi
# Este script desativa o modo AP e tenta conectar o Raspberry a uma rede Wi-Fi configurada previamente no wpa_supplicant

echo "[INFO] Parando serviços do modo AP (hostapd e dnsmasq)..."
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo systemctl disable hostapd
sudo systemctl disable dnsmasq

echo "[INFO] Restaurando IP dinâmico para wlan0..."
sudo ip addr flush dev wlan0
sudo dhclient wlan0

echo "[INFO] Ativando wpa_supplicant..."
sudo systemctl unmask wpa_supplicant
sudo systemctl enable wpa_supplicant
sudo systemctl start wpa_supplicant

echo "[INFO] Conectando como cliente Wi-Fi usando wpa_supplicant.conf..."
sudo wpa_cli -i wlan0 reconfigure

echo "[INFO] Ativando DHCP para obter IP..."
sudo systemctl restart dhcpcd

echo "[OK] Modo cliente ativado. Verifique a conexão com 'iwgetid -r'."
