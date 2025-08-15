#!/bin/bash
# Define o interpretador do script como bash

# Recebe os parâmetros SSID e PASSWORD da rede Wi-Fi via linha de comando
SSID=$1
PASSWORD=$2

# Define arquivo de log para salvar toda a saída do script (stdout e stderr)
LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"
exec >> "$LOG_FILE" 2>&1

# Define o GPIO do LED principal (pino físico 13 = GPIO27)
LED_GPIO=27

# Função que configura e faz o LED piscar rapidamente (0.5s ligado, 0.5s apagado)
piscar_led_rapido() {
  # Exporta o GPIO27 se ainda não estiver exportado para controlar o LED
  if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
    echo $LED_GPIO > /sys/class/gpio/export
    sleep 1
  fi
  # Configura o GPIO27 como saída
  echo out > /sys/class/gpio/gpio$LED_GPIO/direction

  # Loop em background que pisca o LED continuamente
  (
    while true; do
      echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
      sleep 0.5
      echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
      sleep 0.5
    done
  ) &
  # Salva o PID do processo que pisca o LED para poder pará-lo depois
  echo $! > /tmp/led_blink.pid
}

# Chama a função para começar a piscar o LED rápido
piscar_led_rapido

# Verifica se SSID ou PASSWORD não foram passados (vazios)
if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
    echo "[ERRO] Uso: $0 <SSID> <PASSWORD>"
    exit 1
fi

# Define um arquivo lock para evitar que o script rode em duplicidade simultaneamente
LOCKFILE="/tmp/conectando_wifi.lock"
if [ -f "$LOCKFILE" ]; then
    echo "[ERRO] Processo de conexão já em andamento."
    exit 1
fi
# Cria o arquivo lock com o PID do processo atual
echo $$ > "$LOCKFILE"

# Para e desabilita os serviços usados para o modo Access Point
echo "[INFO] Parando e desabilitando serviços de modo Access Point..."
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo systemctl disable hostapd
sudo systemctl disable dnsmasq

# Remove configurações antigas de IP fixo para wlan0 no arquivo dhcpcd.conf
echo "[INFO] Limpando IP fixo de wlan0 no /etc/dhcpcd.conf..."
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf

# Limpa os IPs configurados na interface wlan0
echo "[INFO] Limpando IP da interface wlan0..."
sudo ip addr flush dev wlan0

# Reinicia o serviço de DHCP para aplicar mudanças na interface wlan0
echo "[INFO] Reiniciando o serviço de DHCP (dhcpcd)..."
sudo systemctl restart dhcpcd

# Gera o arquivo wpa_supplicant.conf com a nova rede Wi-Fi configurada (SSID e senha)
echo "[INFO] Gerando nova configuração de rede Wi-Fi..."
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

# Reinicia o wpa_supplicant, responsável pela conexão Wi-Fi
echo "[INFO] Reiniciando wpa_supplicant..."
sudo pkill wpa_supplicant 2>/dev/null || true
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

# Aguarda 5 segundos para o wpa_supplicant tentar conectar
sleep 5

# Verifica o estado da conexão Wi-Fi usando wpa_cli
echo "[INFO] Verificando conexão..."
STATE=$(wpa_cli -i wlan0 status | grep wpa_state= | cut -d= -f2)
# Obtém o endereço IP da interface wlan0 (IPv4)
IP=$(ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)

# Obtém o número serial do Raspberry Pi para gerar um hostname único
SERIAL=$(awk '/Serial/ {print $3}' /proc/cpuinfo)
NEW_HOSTNAME="raspberrypi-$SERIAL"

echo "[INFO] Definindo novo hostname: $NEW_HOSTNAME"

# Define o hostname do sistema para o novo hostname gerado
sudo hostnamectl set-hostname "$NEW_HOSTNAME"
# Atualiza o arquivo /etc/hostname com o novo hostname
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname > /dev/null
# Atualiza o arquivo /etc/hosts para refletir o novo hostname local
sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts

# Reinicia o serviço avahi-daemon para anunciar o novo hostname na rede local
echo "[INFO] Reiniciando avahi-daemon para refletir novo hostname..."
sudo systemctl restart avahi-daemon

# Verifica se a conexão foi completada e se há IP válido
if [[ "$STATE" == "COMPLETED" && -n "$IP" ]]; then
  echo "[SUCESSO] Conectado à rede '$SSID' com IP $IP"
  echo "[INFO] Hostname configurado com sucesso!"
  echo "[INFO] Agora você pode acessar via: http://$NEW_HOSTNAME.local"
  # Remove o arquivo lock para liberar futuras execuções do script
  rm -f "$LOCKFILE"
  exit 0
else
  echo "[ERRO] Não foi possível conectar à rede Wi-Fi."
  echo "[DEBUG] Estado: $STATE | IP: $IP"
  # Remove o arquivo lock mesmo em caso de erro
  rm -f "$LOCKFILE"
  exit 1
fi