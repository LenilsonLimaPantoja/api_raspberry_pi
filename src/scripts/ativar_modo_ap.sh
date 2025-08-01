#!/bin/bash

# Script para ativar modo Access Point com IP fixo

echo "Configurando Raspberry Pi no modo Access Point..."

# Para simplificar, ajuste aqui seu hostapd.conf e dnsmasq.conf se necessário

# IP fixo na wlan0:
sudo ip addr flush dev wlan0
sudo ip addr add 192.168.0.1/24 dev wlan0
sudo ip link set wlan0 up

# Iniciar hostapd e dnsmasq (certifique-se que estão configurados corretamente)
sudo systemctl start hostapd
sudo systemctl start dnsmasq

echo "Modo Access Point ativado. SSID: RaspberryPi-AP, IP: 192.168.0.1"

# --- INSTRUÇÕES IMPORTANTES PARA CONFIGURAÇÃO DO AMBIENTE ---

# 1. Torne este script executável:
#    sudo chmod +x /home/pi/Desktop/api/src/scripts/ativar_modo_ap.sh