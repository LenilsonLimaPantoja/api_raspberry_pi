#!/bin/bash

# Script para monitorar se a conexão Wi-Fi funcionou e ativar modo AP se não funcionar

TIMEOUT=30   # Tempo para esperar a conexão (segundos)
INTERFACE="wlan0"

echo "Aguardando conexão Wi-Fi por $TIMEOUT segundos..."
sleep $TIMEOUT

IP_ATRIBUIDO=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

# Verifica se não tem IP OU se está no IP do modo AP (ex: 192.168.4.X)
if [ -z "$IP_ATRIBUIDO" ] || [[ "$IP_ATRIBUIDO" == 192.168.4.* ]]; then
    echo "Não conectado à rede externa. Ativando modo Access Point..."
    /home/pi/ativar_modo_ap.sh
else
    echo "Conectado com IP $IP_ATRIBUIDO"
fi

# --- INSTRUÇÕES IMPORTANTES PARA CONFIGURAÇÃO DO AMBIENTE ---

# 1. Torne este script executável:
#    sudo chmod +x /home/pi/Desktop/api/src/scripts/watchdog_wifi.sh