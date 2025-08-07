#!/bin/bash

# Recebe os parâmetros SSID e PASSWORD da rede Wi-Fi via linha de comando
SSID=$1
PASSWORD=$2

# Define arquivo de log para salvar a saída do script
LOG_FILE="/home/pi/Desktop/api_raspberry_pi/src/log/conectar_wifi.log"
exec >> "$LOG_FILE" 2>&1

# LED principal (pino físico 13 = GPIO27)
LED_GPIO=27

# Função para piscar LED rapidamente
piscar_led_rapido() {
  if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
    echo $LED_GPIO > /sys/class/gpio/export
    sleep 1
  fi
  echo out > /sys/class/gpio/gpio$LED_GPIO/direction

  (
    while true; do
      echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
      sleep 0.3
      echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
      sleep 0.3
    done
  ) &
  echo $! > /tmp/led_blink.pid
}

piscar_led_rapido

if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
    echo "[ERRO] Uso: $0 <SSID> <PASSWORD>"
    exit 1
fi

LOCKFILE="/tmp/conectando_wifi.lock"
if [ -f "$LOCKFILE" ]; then
    echo "[ERRO] Processo de conexão já em andamento."
    exit 1
fi
echo $$ > "$LOCKFILE"

echo "[INFO] Parando e desabilitando serviços de modo Access Point..."
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo systemctl disable hostapd
sudo systemctl disable dnsmasq

echo "[INFO] Limpando IP fixo de wlan0 no /etc/dhcpcd.conf..."
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf

echo "[INFO] Limpando IP da interface wlan0..."
sudo ip addr flush dev wlan0

echo "[INFO] Reiniciando o serviço de DHCP (dhcpcd)..."
sudo systemctl restart dhcpcd

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

echo "[INFO] Reiniciando wpa_supplicant..."
sudo pkill wpa_supplicant 2>/dev/null || true
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

sleep 5

echo "[INFO] Verificando conexão..."
STATE=$(wpa_cli -i wlan0 status | grep wpa_state= | cut -d= -f2)
IP=$(ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)

SERIAL=$(awk '/Serial/ {print $3}' /proc/cpuinfo)
NEW_HOSTNAME="raspberrypi-$SERIAL"

echo "[INFO] Definindo novo hostname: $NEW_HOSTNAME"

sudo hostnamectl set-hostname "$NEW_HOSTNAME"
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname > /dev/null
sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts

echo "[INFO] Reiniciando avahi-daemon para refletir novo hostname..."
sudo systemctl restart avahi-daemon

if [[ "$STATE" == "COMPLETED" && -n "$IP" ]]; then
  echo "[SUCESSO] Conectado à rede '$SSID' com IP $IP"
  echo "[INFO] Hostname configurado com sucesso!"
  echo "[INFO] Agora você pode acessar via: http://$NEW_HOSTNAME.local"
  rm -f "$LOCKFILE"
  exit 0
else
  echo "[ERRO] Não foi possível conectar à rede Wi-Fi."
  echo "[DEBUG] Estado: $STATE | IP: $IP"
  rm -f "$LOCKFILE"
  exit 1
fi