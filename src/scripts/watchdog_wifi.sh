#!/bin/bash
# Define o interpretador do script como bash

TIMEOUT_TOTAL=25
WAIT_TIME=5
INTERFACE="wlan0"
LED_GPIO=27
ATIVAR_AP_SCRIPT="./ativar_modo_ap_reboot.sh"

# Configura o GPIO do LED para saída, se ainda não estiver exportado
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

echo "Iniciando watchdog Wi-Fi..."

MAX_TRIES=$((TIMEOUT_TOTAL / WAIT_TIME))

for ((i=1; i<=MAX_TRIES; i++)); do
  IP_ATRIBUIDO=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

  if [[ -n "$IP_ATRIBUIDO" && "$IP_ATRIBUIDO" != 192.168.4.* ]]; then
    echo "Conectado com IP $IP_ATRIBUIDO"
    led_on
    rm -f /tmp/conectando_wifi.lock
    exit 0
  fi

  echo "Tentativa $i/$MAX_TRIES... aguardando..."
  sleep $WAIT_TIME
done

echo "Não conectado após $MAX_TRIES tentativas. Apagando LED."
led_off

echo "Ativando modo AP por não conseguir conexão Wi-Fi"
bash "$ATIVAR_AP_SCRIPT"

rm -f /tmp/conectando_wifi.lock
exit 1
