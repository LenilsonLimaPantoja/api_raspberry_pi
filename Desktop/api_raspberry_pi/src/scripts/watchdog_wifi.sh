#!/bin/bash

TIMEOUT_TOTAL=25
WAIT_TIME=5
INTERFACE="wlan0"
LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"
LED_GPIO=27
ATIVAR_AP_SCRIPT="/home/pi/Desktop/api_raspberry_pi/src/scripts/ativar_modo_ap_reboot.sh"

# Setup GPIO
if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
  echo $LED_GPIO > /sys/class/gpio/export
  sleep 1
fi
echo out > /sys/class/gpio/gpio$LED_GPIO/direction

led_on() {
  if [ -f /tmp/led_blink.pid ]; then
    kill "$(cat /tmp/led_blink.pid)" 2>/dev/null
    rm -f /tmp/led_blink.pid
  fi
  echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
}

led_off() {
  if [ -f /tmp/led_blink.pid ]; then
    kill "$(cat /tmp/led_blink.pid)" 2>/dev/null
    rm -f /tmp/led_blink.pid
  fi
  echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

exec >> "$LOG_FILE" 2>&1

log "Iniciando watchdog Wi-Fi..."

MAX_TRIES=$((TIMEOUT_TOTAL / WAIT_TIME))

for ((i=1; i<=MAX_TRIES; i++)); do
  IP_ATRIBUIDO=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

  if [[ -n "$IP_ATRIBUIDO" && "$IP_ATRIBUIDO" != 192.168.4.* ]]; then
    log "Conectado com IP $IP_ATRIBUIDO"
    led_on
    rm -f /tmp/conectando_wifi.lock
    exit 0
  fi

  log "Tentativa $i/$MAX_TRIES... aguardando..."
  sleep $WAIT_TIME
done

log "Não conectado após $MAX_TRIES tentativas. Apagando LED."
led_off

log "Ativando modo AP por não conseguir conexão Wi-Fi"
bash "$ATIVAR_AP_SCRIPT"

rm -f /tmp/conectando_wifi.lock
exit 1