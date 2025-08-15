#!/bin/bash
# Define o interpretador do script como bash

# Tempo total de espera para tentar conexão Wi-Fi (em segundos)
TIMEOUT_TOTAL=25
# Tempo entre tentativas (em segundos)
WAIT_TIME=5
# Interface de rede Wi-Fi que será monitorada
INTERFACE="wlan0"
# Caminho do arquivo de log onde será salvo o output do script
LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"
# GPIO do LED que indica status (pino físico 13 = GPIO27)
LED_GPIO=27
# Caminho do script que ativa o modo Access Point (AP) em caso de falha
ATIVAR_AP_SCRIPT="/home/pi/Desktop/api_raspberry_pi/src/scripts/ativar_modo_ap_reboot.sh"

# Configura o GPIO do LED para saída, se ainda não estiver exportado
if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
  echo $LED_GPIO > /sys/class/gpio/export
  sleep 1
fi
echo out > /sys/class/gpio/gpio$LED_GPIO/direction

# Função para ligar o LED, finalizando o processo de piscar caso esteja ativo
led_on() {
  if [ -f /tmp/led_blink.pid ]; then
    kill "$(cat /tmp/led_blink.pid)" 2>/dev/null
    rm -f /tmp/led_blink.pid
  fi
  echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
}

# Função para desligar o LED, finalizando o processo de piscar caso esteja ativo
led_off() {
  if [ -f /tmp/led_blink.pid ]; then
    kill "$(cat /tmp/led_blink.pid)" 2>/dev/null
    rm -f /tmp/led_blink.pid
  fi
  echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
}

# Função para registrar mensagens no log com timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Redireciona stdout e stderr para o arquivo de log
exec >> "$LOG_FILE" 2>&1

log "Iniciando watchdog Wi-Fi..."

# Calcula o número máximo de tentativas com base no tempo total e tempo de espera
MAX_TRIES=$((TIMEOUT_TOTAL / WAIT_TIME))

# Loop de tentativas para verificar se a interface recebeu um IP válido
for ((i=1; i<=MAX_TRIES; i++)); do
  # Obtém o IP IPv4 da interface wlan0
  IP_ATRIBUIDO=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

  # Verifica se o IP existe e não está na faixa 192.168.4.x (provavelmente IP do AP)
  if [[ -n "$IP_ATRIBUIDO" && "$IP_ATRIBUIDO" != 192.168.4.* ]]; then
    log "Conectado com IP $IP_ATRIBUIDO"
    led_on  # Liga o LED para indicar sucesso
    rm -f /tmp/conectando_wifi.lock  # Remove arquivo lock para liberar execuções futuras
    exit 0  # Sai do script com sucesso
  fi

  log "Tentativa $i/$MAX_TRIES... aguardando..."
  sleep $WAIT_TIME
done

# Caso não tenha conseguido IP após todas as tentativas
log "Não conectado após $MAX_TRIES tentativas. Apagando LED."
led_off  # Apaga o LED para indicar falha

log "Ativando modo AP por não conseguir conexão Wi-Fi"
bash "$ATIVAR_AP_SCRIPT"  # Executa script para colocar o Raspberry Pi em modo Access Point

rm -f /tmp/conectando_wifi.lock  # Remove o arquivo lock para liberar futuras execuções
exit 1  # Sai do script indicando erro