#!/bin/bash

# Define o caminho do arquivo de log onde as saídas e erros serão redirecionados
LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"
exec >> "$LOG_FILE" 2>&1
# Redireciona stdout e stderr para o arquivo de log

echo "[INFO] --- Iniciando modo Access Point ---"
echo "[INFO] Desconectando Wi-Fi atual e limpando configurações..."

# Limpa as configurações anteriores do Wi-Fi para evitar conflitos
echo "[INFO] Limpando redes Wi-Fi salvas..."
# Sobrescreve o arquivo wpa_supplicant.conf com um conteúdo "limpo" para modo AP
sudo bash -c 'echo -e "# wpa_supplicant.conf limpo para modo AP\n" > /etc/wpa_supplicant/wpa_supplicant.conf'
# Para o serviço wpa_supplicant que gerencia conexões Wi-Fi
sudo systemctl stop wpa_supplicant

# Remove arquivos de configuração antigos do modo Access Point, caso existam
sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -f /etc/dnsmasq.conf

# Configura o hostapd para criar o ponto de acesso
echo "[INFO] Criando arquivo hostapd.conf..."
# Define o arquivo de configuração que o hostapd deve usar
sudo tee /etc/default/hostapd > /dev/null <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

# Cria o arquivo de configuração do hostapd com as definições do AP
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
# Interface Wi-Fi usada
driver=nl80211
# Driver do hostapd para interface wlan0
ssid=Balanca-AP
# Nome da rede Wi-Fi do ponto de acesso
hw_mode=g
# Modo wireless 802.11g
channel=7
# Canal Wi-Fi
wmm_enabled=0
# Desabilita WMM (Wi-Fi Multimedia)
macaddr_acl=0
# Sem controle de MAC
auth_algs=1
# Algoritmo de autenticação
ignore_broadcast_ssid=0
# SSID visível para clientes
wpa=2
# WPA2 habilitado
wpa_passphrase=12345678
# Senha da rede Wi-Fi do AP
wpa_key_mgmt=WPA-PSK
# Gerenciamento de chave WPA-PSK
rsn_pairwise=CCMP
# Tipo de criptografia
EOF

# Configura o dnsmasq, que fornece DHCP para clientes conectados
echo "[INFO] Criando arquivo dnsmasq.conf..."
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0               # Interface para DHCP
dhcp-range=192.168.0.50,192.168.0.150,12h  # Faixa de IPs para clientes com lease de 12h
EOF

# Configura IP fixo para a interface wlan0
echo "[INFO] Configurando IP fixo para wlan0..."
# Remove configurações antigas referentes a wlan0 no dhcpcd.conf para evitar conflito
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf
# Adiciona nova configuração para IP estático no wlan0 e desabilita wpa_supplicant para esta interface
sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF
interface wlan0
static ip_address=192.168.0.1/24
nohook wpa_supplicant
EOF

# Reinicia e habilita os serviços para aplicar as configurações
echo "[INFO] Reiniciando serviços..."
sudo systemctl restart dhcpcd
# Reinicia serviço DHCP client daemon
sudo systemctl unmask hostapd
# Remove qualquer bloqueio no hostapd
sudo systemctl enable hostapd
# Habilita hostapd para iniciar no boot
sudo systemctl enable dnsmasq
# Habilita dnsmasq para iniciar no boot
sudo systemctl restart hostapd
# Reinicia hostapd para aplicar configurações
sudo systemctl restart dnsmasq
# Reinicia dnsmasq para aplicar configurações

echo "[SUCESSO] Modo Access Point configurado com sucesso. Reiniciando em 5 segundos..."
sleep 5
# Pausa para o usuário ver o log antes do reboot
sudo reboot
# Reinicia o sistema para aplicar todas as configurações
