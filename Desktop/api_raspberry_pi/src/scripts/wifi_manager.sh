#!/bin/bash

# Variáveis de configuração
PING_TARGET="8.8.8.8"        # Endereço IP para testar conexão com a internet (Google DNS)
MAX_TRIES=15                 # Número máximo de tentativas de ping para verificar a internet
WAIT_TIME=2                  # Tempo de espera (em segundos) entre as tentativas de ping
INITIAL_WAIT=10              # Tempo de espera inicial após tentar conexão (foi reduzido para agilidade)

# Função para imprimir logs com timestamp
log() {
  echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1"
}

# Função para limpar configuração do modo Access Point (AP)
cleanup_ap() {
  log "Removendo IP fixo do modo AP, se existir..."
  # Remove IP fixo da interface wlan0 (caso esteja configurado para modo AP)
  sudo ip addr del 192.168.0.1/24 dev wlan0 2>/dev/null || true

  log "Parando serviços do modo AP (hostapd e dnsmasq)..."
  # Para os serviços de Access Point
  sudo systemctl stop hostapd
  sudo systemctl stop dnsmasq
}

# Função para iniciar o modo Access Point (AP)
start_ap() {
  log "Configurando IP fixo para modo AP..."
  # Define IP fixo para wlan0 no modo AP
  sudo ip addr add 192.168.0.1/24 dev wlan0

  log "Iniciando serviços do modo AP..."
  # Inicia serviços de Access Point
  sudo systemctl start hostapd
  sudo systemctl start dnsmasq
}

# Função para iniciar o modo cliente Wi-Fi (modo normal)
start_wifi_client() {
  log "Modo Cliente: tentando conectar ao Wi-Fi..."

  # Remove configurações de AP para não interferir
  cleanup_ap

  log "Reiniciando serviço DHCP (dhcpcd)..."
  sudo systemctl restart dhcpcd

  log "Forçando wpa_supplicant manualmente..."
  # Finaliza processos anteriores do wpa_supplicant, se houver
  sudo pkill wpa_supplicant

  # Inicia wpa_supplicant em background com a configuração fornecida
  sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

  sleep 5

  log "Solicitando IP via dhclient..."
  # Solicita IP via DHCP diretamente
  sudo dhclient wlan0

  log "Aguardando $INITIAL_WAIT segundos para estabilizar conexão..."
  sleep $INITIAL_WAIT
}

# Verifica se existe uma configuração válida no wpa_supplicant.conf
if grep -q ssid /etc/wpa_supplicant/wpa_supplicant.conf; then
  log "Configuração Wi-Fi encontrada."

  # Tenta conectar como cliente Wi-Fi
  start_wifi_client

  # Verifica conectividade com a internet (via ping)
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

  # Após todas as tentativas sem sucesso, entra em modo AP
  log "Não foi possível detectar internet. Entrando no modo AP..."
  start_ap
  exit 0

else
  # Se não houver configuração válida, entra diretamente em modo AP
  log "Nenhuma configuração Wi-Fi válida encontrada. Entrando no modo AP..."
  start_ap
  exit 0
fi
