#!/bin/bash
# Define o interpretador do script (bash)

LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"
exec >> "$LOG_FILE" 2>&1
# Redireciona toda a saída (stdout e stderr) do script para o arquivo de log definido em LOG_FILE

# Apaga GPIO27 (pino físico 13)
GPIO27=27
if [ ! -d /sys/class/gpio/gpio$GPIO27 ]; then
  echo $GPIO27 > /sys/class/gpio/export
  sleep 1
fi
echo out > /sys/class/gpio/gpio$GPIO27/direction
echo 0 > /sys/class/gpio/gpio$GPIO27/value
# Exporta o GPIO27 (pino físico 13) para controle via sysfs, configura como saída e seta o valor 0 (desligado)

# Configura GPIO22 (pino físico 15) para LED piscando
LED_GPIO=22  # pino físico 15 (GPIO22)

echo "[INFO] --- Iniciando modo Access Point ---"
# Mensagem informando que o modo Access Point está sendo iniciado

if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
  echo $LED_GPIO > /sys/class/gpio/export
  sleep 1
fi
echo out > /sys/class/gpio/gpio$LED_GPIO/direction
# Exporta o GPIO22 (pino físico 15), configura como saída para controlar o LED

(
  while true; do
    echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
    sleep 0.5
    echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
    sleep 0.5
  done
) &
LED_PID=$!
# Loop em background que faz o LED piscar a cada 0.5 segundos (liga e desliga),
# armazenando o PID do processo para controlar depois

echo "[INFO] Desconectando Wi-Fi atual e limpando configurações..."
# Informativo que a conexão Wi-Fi atual será desconectada e configurações serão limpas

echo "[INFO] Limpando redes Wi-Fi salvas..."
sudo bash -c 'echo -e "# wpa_supplicant.conf limpo para modo AP\n" > /etc/wpa_supplicant/wpa_supplicant.conf'
# Sobrescreve o arquivo wpa_supplicant.conf com um conteúdo vazio comentado para limpar redes salvas

sudo systemctl stop wpa_supplicant
# Para o serviço wpa_supplicant que gerencia conexões Wi-Fi

sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -f /etc/dnsmasq.conf
# Remove configurações antigas dos serviços hostapd e dnsmasq

echo "[INFO] Criando arquivo hostapd.conf..."
sudo tee /etc/default/hostapd > /dev/null <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF
# Define no arquivo /etc/default/hostapd qual arquivo de configuração o hostapd deve usar

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
# Cria o arquivo de configuração do hostapd para transformar wlan0 em um Access Point com SSID "Balanca-AP" e senha "12345678"

echo "[INFO] Criando arquivo dnsmasq.conf..."
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
dhcp-range=192.168.0.50,192.168.0.150,12h
EOF
# Cria arquivo de configuração do dnsmasq que gerencia DHCP para distribuir IPs entre 192.168.0.50 e 192.168.0.150 na interface wlan0

echo "[INFO] Configurando IP fixo para wlan0..."
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf
# Remove configurações antigas referentes a wlan0 do arquivo dhcpcd.conf para evitar conflito

sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF
interface wlan0
static ip_address=192.168.0.1/24
nohook wpa_supplicant
EOF
# Adiciona configuração para wlan0 usar IP fixo 192.168.0.1 com máscara /24 e para não iniciar wpa_supplicant nessa interface

echo "[INFO] Reiniciando serviços..."
sudo systemctl restart dhcpcd
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq
# Reinicia o serviço de gerenciamento de DHCP (dhcpcd),
# remove possíveis bloqueios (unmask) no hostapd,
# habilita os serviços hostapd e dnsmasq para iniciarem junto com o sistema,
# e reinicia os serviços hostapd e dnsmasq para aplicar as configurações

echo "[SUCESSO] Modo Access Point configurado com sucesso. Reiniciando em 1 segundo..."
sleep 1
# Mensagem de sucesso e pausa de 1 segundo antes de reiniciar

kill $LED_PID
echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
# Para o processo que estava piscando o LED e desliga o LED

sudo reboot
# Reinicia o Raspberry Pi para aplicar as mudanças