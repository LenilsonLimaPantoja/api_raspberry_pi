#!/bin/bash

# Script para configurar Wi-Fi no Raspberry Pi atualizando o arquivo wpa_supplicant.conf
# e reiniciando o serviço para aplicar as mudanças.

# Parâmetros:
# $1 - SSID da rede Wi-Fi
# $2 - Senha (PSK) da rede Wi-Fi

SSID=$1
PASSWORD=$2

if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
    echo "Uso: $0 <SSID> <PASSWORD>"
    exit 1
fi

echo "Parando serviços de modo Access Point para liberar wlan0..."
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

echo "Removendo IP fixo da wlan0 e reiniciando dhcpcd para DHCP normal..."
sudo ip addr flush dev wlan0
sudo systemctl restart dhcpcd

echo "Configurando Wi-Fi para a rede '$SSID'..."

cat > /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=BR

network={
    ssid="$SSID"
    psk="$PASSWORD"
    key_mgmt=WPA-PSK
}
EOF

wpa_cli -i wlan0 reconfigure

if [ $? -eq 0 ]; then
    echo "Wi-Fi configurado para a rede '$SSID' com sucesso."
    exit 0
else
    echo "Erro ao reiniciar o serviço Wi-Fi."
    exit 1
fi

# --- INSTRUÇÕES IMPORTANTES PARA CONFIGURAÇÃO DO AMBIENTE ---

# 1. Torne este script executável:
#    sudo chmod +x /home/pi/Desktop/api/src/scripts/configurar_wifi.sh

# 2. Para permitir que o usuário 'pi' execute o script com sudo sem pedir senha,
#    edite o sudoers com o comando:
#    sudo visudo

#    No final do arquivo sudoers, adicione esta linha:
#    pi ALL=(ALL) NOPASSWD: /home/pi/Desktop/api/src/scripts/configurar_wifi.sh

#    Isso garante que somente este script específico seja executado com sudo sem senha,
#    aumentando a segurança.

# 3. A partir do Node.js, chame o script assim:
#    execFile('sudo', ['/home/pi/Desktop/api/src/scripts/configurar_wifi.sh', ssid, password], callback);

# 4. Certifique-se que o seu serviço Node.js está rodando como usuário 'pi' (ou ajuste o sudoers para o usuário correto).

# 5. Caso precise depurar, você pode executar manualmente no terminal:
#    sudo /home/pi/Desktop/api/src/scripts/configurar_wifi.sh "NomeRede" "SenhaRede"

# 6. Caso o Raspberry Pi esteja conectado por SSH, cuidado ao alterar a rede Wi-Fi, 
#    pois pode perder a conexão se os dados estiverem incorretos.

# 7. Se quiser adicionar múltiplas redes, terá que ajustar o script para concatenar redes no arquivo wpa_supplicant.conf.
