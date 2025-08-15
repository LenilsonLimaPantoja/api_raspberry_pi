#!/bin/bash
# Define que o interpretador do script é bash

# Variáveis de configuração
PING_TARGET="8.8.8.8"        # Endereço IP para teste de conexão (Google DNS)
MAX_TRIES=15                 # Número máximo de tentativas para checar a conexão
WAIT_TIME=2                  # Tempo em segundos entre as tentativas
INITIAL_WAIT=10              # Tempo de espera inicial para estabilizar a conexão Wi-Fi

# Configura GPIO27 (pino físico 13) para controlar o LED, se ainda não estiver configurado
if [ ! -d /sys/class/gpio/gpio27 ]; then
  echo 27 > /sys/class/gpio/export
  sleep 1
fi
echo out > /sys/class/gpio/gpio27/direction

# Função para logar mensagens com timestamp
log() {
  echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1"
}

# Função para ligar o LED (valor 1)
led_on() {
  echo 1 > /sys/class/gpio/gpio27/value
}

# Função para apagar o LED (valor 0)
led_off() {
  echo 0 > /sys/class/gpio/gpio27/value
}

# Função para piscar o LED 10 vezes com intervalo de 0,5s ligado e 0,5s apagado
led_blink_10x() {
  for i in {1..10}; do
    echo 1 > /sys/class/gpio/gpio27/value
    sleep 0.5
    echo 0 > /sys/class/gpio/gpio27/value
    sleep 0.5
  done
}

# Função para limpar configuração do modo Access Point (AP)
cleanup_ap() {
  log "Removendo IP fixo do modo AP, se existir..."
  sudo ip addr del 192.168.0.1/24 dev wlan0 2>/dev/null || true  # Remove IP fixo da interface wlan0 (modo AP)
  log "Parando serviços do modo AP (hostapd e dnsmasq)..."
  sudo systemctl stop hostapd     # Para o serviço hostapd (AP Wi-Fi)
  sudo systemctl stop dnsmasq     # Para o serviço dnsmasq (servidor DHCP/DNS do AP)
}

# Função para iniciar o modo Access Point (AP)
start_ap() {
  log "Configurando IP fixo para modo AP..."
  sudo ip addr add 192.168.0.1/24 dev wlan0  # Adiciona IP fixo na interface wlan0 para o AP
  log "Iniciando serviços do modo AP..."
  sudo systemctl start hostapd   # Inicia o serviço hostapd
  sudo systemctl start dnsmasq   # Inicia o serviço dnsmasq
  log "LED piscando 10 vezes (modo AP)..."
  led_blink_10x                 # Pisca o LED 10 vezes para indicar modo AP
}

# Função para iniciar o modo cliente Wi-Fi, conectando à rede
start_wifi_client() {
  log "Modo Cliente: tentando conectar ao Wi-Fi..."
  cleanup_ap                    # Limpa qualquer configuração de AP que esteja ativa
  log "Reiniciando serviço DHCP (dhcpcd)..."
  sudo systemctl restart dhcpcd # Reinicia serviço DHCP para renovar IP
  log "Forçando wpa_supplicant manualmente..."
  sudo pkill wpa_supplicant     # Mata qualquer processo wpa_supplicant existente
  sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf  # Inicia wpa_supplicant com config atual
  sleep 5                      # Espera 5 segundos para estabilizar a conexão
  log "Solicitando IP via dhclient..."
  sudo dhclient wlan0           # Solicita um IP via DHCP na interface wlan0
  log "Aguardando $INITIAL_WAIT segundos para estabilizar conexão..."
  sleep $INITIAL_WAIT          # Espera o tempo configurado para estabilizar a conexão
  log "LED aceso fixo (modo cliente Wi-Fi)..."
  led_on                      # Acende o LED fixo indicando conexão Wi-Fi ativa
}

# === INÍCIO DO SCRIPT PRINCIPAL ===

# Verifica se existe configuração válida de SSID no arquivo wpa_supplicant.conf
if grep -q ssid /etc/wpa_supplicant/wpa_supplicant.conf; then
  log "Configuração Wi-Fi encontrada."
  start_wifi_client           # Tenta conectar como cliente Wi-Fi

  TRY=1
  # Loop para tentar pingar o endereço de teste até o limite de tentativas
  while [[ $TRY -le $MAX_TRIES ]]; do
    if ping -c 1 -W 2 "$PING_TARGET" > /dev/null 2>&1; then
      log "Internet detectada após $TRY tentativa(s)."
      cleanup_ap              # Se conectado, limpa modo AP (se estiver ativo)
      exit 0                 # Sai do script com sucesso
    else
      log "Tentativa $TRY/$MAX_TRIES sem resposta. Aguardando $WAIT_TIME segundos..."
      sleep $WAIT_TIME
      ((TRY++))              # Incrementa o contador de tentativas
    fi
  done

  # Se não conseguiu conexão após todas as tentativas, ativa modo AP
  log "Não foi possível detectar internet. Entrando no modo AP..."
  start_ap
  exit 0
else
  # Se não encontrou configuração Wi-Fi válida, ativa modo AP diretamente
  log "Nenhuma configuração Wi-Fi válida encontrada. Entrando no modo AP..."
  start_ap
  exit 0
fi