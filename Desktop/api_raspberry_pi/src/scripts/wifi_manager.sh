#!/bin/bash

# Variáveis de configuração
PING_TARGET="8.8.8.8"        # Google DNS para teste
MAX_TRIES=15
WAIT_TIME=2
INITIAL_WAIT=10

# Configura GPIO27 para o LED (se ainda não estiver configurado)
if [ ! -d /sys/class/gpio/gpio27 ]; then
  echo 27 > /sys/class/gpio/export
  sleep 1
fi
echo out > /sys/class/gpio/gpio27/direction

log() {
  echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1"
}

# Função para ligar LED fixo
led_on() {
  echo 1 > /sys/class/gpio/gpio27/value
}

# Função para apagar LED
led_off() {
  echo 0 > /sys/class/gpio/gpio27/value
}

# Função para piscar 10 vezes o LED
led_blink_10x() {
  for i in {1..10}; do
    echo 1 > /sys/class/gpio/gpio27/value
    sleep 0.5
    echo 0 > /sys/class/gpio/gpio27/value
    sleep 0.5
  done
}

cleanup_ap() {
  log "Removendo IP fixo do modo AP, se existir..."
  sudo ip addr del 192.168.0.1/24 dev wlan0 2>/dev/null || true
  log "Parando serviços do modo AP (hostapd e dnsmasq)..."
  sudo systemctl stop hostapd
  sudo systemctl stop dnsmasq
}

start_ap() {
  log "Configurando IP fixo para modo AP..."
  sudo ip addr add 192.168.0.1/24 dev wlan0
  log "Iniciando serviços do modo AP..."
  sudo systemctl start hostapd
  sudo systemctl start dnsmasq
  log "LED piscando 10 vezes (modo AP)..."
  led_blink_10x
}

start_wifi_client() {
  log "Modo Cliente: tentando conectar ao Wi-Fi..."
  cleanup_ap
  log "Reiniciando serviço DHCP (dhcpcd)..."
  sudo systemctl restart dhcpcd
  log "Forçando wpa_supplicant manualmente..."
  sudo pkill wpa_supplicant
  sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
  sleep 5
  log "Solicitando IP via dhclient..."
  sudo dhclient wlan0
  log "Aguardando $INITIAL_WAIT segundos para estabilizar conexão..."
  sleep $INITIAL_WAIT
  log "LED aceso fixo (modo cliente Wi-Fi)..."
  led_on
}

# MAIN
if grep -q ssid /etc/wpa_supplicant/wpa_supplicant.conf; then
  log "Configuração Wi-Fi encontrada."
  start_wifi_client
  TRY=1
  while [[ $TRY -le $MAX_TRIES ]]; do
    if ping -c 1 -W 2 "$PING_TARGET" > /dev/null 2>&1; then
      log "Internet detectada após $TRY tentativa(s)."
      cleanup_ap
      exit 0
    else
      log "Tentativa $TRY/$MAX_TRIES sem resposta. Aguardando $WAIT_TIME segundos..."
      sleep $WAIT_TIME
      ((TRY++))
    fi
  done
  log "Não foi possível detectar internet. Entrando no modo AP..."
  start_ap
  exit 0
else
  log "Nenhuma configuração Wi-Fi válida encontrada. Entrando no modo AP..."
  start_ap
  exit 0
fi