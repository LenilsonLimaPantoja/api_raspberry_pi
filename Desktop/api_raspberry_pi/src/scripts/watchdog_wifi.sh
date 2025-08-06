#!/bin/bash

# Tempo total máximo para aguardar a conexão Wi-Fi (em segundos)
TIMEOUT_TOTAL=25

# Intervalo entre cada verificação (em segundos)
WAIT_TIME=5

# Interface de rede Wi-Fi que será monitorada
INTERFACE="wlan0"

# Caminho do arquivo de log onde as mensagens serão salvas
LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"

# Redireciona stdout e stderr para o arquivo de log
exec >> "$LOG_FILE" 2>&1

echo "[INFO] Iniciando watchdog Wi-Fi por $TIMEOUT_TOTAL segundos..."

# Calcula o número máximo de tentativas com base no tempo total e intervalo
MAX_TRIES=$((TIMEOUT_TOTAL / WAIT_TIME))

# Loop para verificar repetidamente se a interface wlan0 recebeu um IP válido
for ((i=1; i<=MAX_TRIES; i++)); do
    # Captura o IP IPv4 da interface wlan0
    IP_ATRIBUIDO=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    # Verifica se o IP existe e não é um IP da faixa do modo Access Point (ex: 192.168.4.x)
    if [[ -n "$IP_ATRIBUIDO" && "$IP_ATRIBUIDO" != 192.168.4.* ]]; then
        echo "[SUCESSO] Conectado com IP $IP_ATRIBUIDO"
        # Remove o arquivo de bloqueio que pode indicar tentativa de conexão
        rm -f /tmp/conectando_wifi.lock
        exit 0
        # Sai com sucesso
    fi

    # Se não conectado ainda, loga a tentativa e aguarda o tempo configurado antes de tentar novamente
    echo "[INFO] Tentativa $i/$MAX_TRIES... aguardando..."
    sleep $WAIT_TIME
done

# Caso não conecte após o número máximo de tentativas, ativa o modo Access Point
echo "[ERRO] Não conectado após $MAX_TRIES tentativas. Ativando modo Access Point..."

# Remove arquivo de bloqueio para liberar estado
rm -f /tmp/conectando_wifi.lock

# Executa o script que ativa o modo Access Point e reinicia o sistema
/home/pi/Desktop/api_raspberry_pi/src/scripts/ativar_modo_ap_reboot.sh
