#!/bin/bash
# Define que o interpretador do script será o bash. Todos os comandos serão executados pelo shell bash.

LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"
# caminho do arquivo de log.

exec >> "$LOG_FILE" 2>&1
# Redireciona toda a saída e erros para o arquivo de log.

# GPIO27 (pino físico 13)
GPIO27=27

if [ ! -d /sys/class/gpio/gpio$GPIO27 ]; then
  # Verifica se o diretório do GPIO27 existe. 
  # '-d' verifica se é um diretório, e '!' nega, então a condição é verdadeira se o diretório não existir.
  # Se o diretório não existir, significa que o GPIO ainda não foi exportado para controle pelo sistema.

  echo $GPIO27 > /sys/class/gpio/export
  # Exporta o GPIO27 para que possa ser controlado via sysfs.
  sleep 1
  # Aguarda 1 segundo para garantir que o sistema registre o GPIO exportado.
fi

echo out > /sys/class/gpio/gpio$GPIO27/direction
# Define o GPIO27 como saída. Isso permite escrever 0 ou 1 no pino para desligar ou ligar algo.

echo 0 > /sys/class/gpio/gpio$GPIO27/value
# Inicializa o GPIO27 com valor 0 (desligado).

# CONFIGURAÇÃO DO LED INDICADOR (GPIO22, pino físico 15)
LED_GPIO=22

if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
  echo $LED_GPIO > /sys/class/gpio/export
  sleep 1
fi

echo out > /sys/class/gpio/gpio$LED_GPIO/direction
# Define o GPIO22 do LED como saída.

# Loop em background que pisca o LED enquanto o AP está sendo configurado
(
  while true; do
    echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
    # Liga o LED
    sleep 0.5
    echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
    # Desliga o LED
    sleep 0.5
  done
) &
# Executa o loop em background
LED_PID=$!
# Armazena o PID do processo em LED_PID para poder parar o loop depois

# LIMPA A CONFIGURAÇÃO WIFI
echo "[INFO] Desconectando Wi-Fi e limpando configurações."
# Mensagem de log

echo "[INFO] Limpando redes Wi-Fi salvas."
sudo bash -c 'echo -e "# wpa_supplicant.conf limpo para modo AP\n" > /etc/wpa_supplicant/wpa_supplicant.conf'
# Sobrescreve o arquivo de configuração wpa_supplicant.conf com um comentário vazio.
# Isso limpa redes Wi-Fi salvas para não ter conflito com o AP.

sudo systemctl stop wpa_supplicant
# Para o serviço wpa_supplicant que gerencia conexões Wi-Fi automáticas.

sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -f /etc/dnsmasq.conf
# Remove arquivos antigos de configuração do hostapd e dnsmasq, para não ter conflitos.

# CONFIGURAÇÃO DO HOSTAPD (Access Point)
echo "[INFO] Criando arquivo hostapd.conf."
sudo tee /etc/default/hostapd > /dev/null <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF
# Define qual arquivo de configuração o hostapd deve usar quando iniciar.

sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
# Interface de rede que será usada como AP
interface=wlan0
# Driver utilizado para Wi-Fi no Raspberry Pi
driver=nl80211
# Nome da rede Wi-Fi criada
ssid=Balanca-AP
# Define o modo de operação 802.11g
hw_mode=g
# Canal de transmissão Wi-Fi
channel=7
# Desabilita WMM (Wireless Multimedia Extensions)
wmm_enabled=0
# Permite todos os endereços MAC
macaddr_acl=0
# Algoritmo de autenticação (1 = WPA)
auth_algs=1
# SSID será visível
ignore_broadcast_ssid=0
# Define WPA2
wpa=2
# Senha da rede Wi-Fi
wpa_passphrase=12345678
# Gerenciamento de chaves WPA-PSK
wpa_key_mgmt=WPA-PSK
# Define cifragem AES
rsn_pairwise=CCMP
EOF
# Cria o arquivo de configuração do hostapd para transformar a interface wlan0 em um Access Point.

# CONFIGURAÇÃO DO DNSMASQ (DHCP)
echo "[INFO] Criando arquivo dnsmasq.conf."
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
# Interface que fornecerá IP via DHCP
interface=wlan0
dhcp-range=192.168.0.50,192.168.0.150,12h
# Faixa de IPs que podem ser distribuídos pelo DHCP (50 a 150) e duração de 12 horas
EOF

# CONFIGURAÇÃO DE IP FIXO PARA WLAN0
echo "[INFO] Configurando IP fixo para wlan0."
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf
# Remove configurações antigas de wlan0 no dhcpcd.conf para evitar conflitos

sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF
interface wlan0
static ip_address=192.168.0.1/24
nohook wpa_supplicant
EOF
# Define IP fixo 192.168.0.1/24 para wlan0 e impede wpa_supplicant de iniciar nessa interface.

# SERVIÇOS DE REDE
echo "[INFO] Serviços de rede."
sudo systemctl unmask hostapd
# Remove possíveis bloqueios do hostapd
sudo systemctl enable hostapd
# Habilita hostapd no boot
sudo systemctl enable dnsmasq
# Habilita dnsmasq no boot

# FINALIZAÇÃO
echo "[SUCESSO] Modo Access Point configurado. Reiniciando em 1 segundo."
sleep 1

kill $LED_PID
echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
# Para o loop de piscar o LED e desliga o LED

sudo reboot
# Reinicia o Raspberry Pi para aplicar as mudanças de rede