#!/bin/bash
# Define o interpretador do script como bash

# Recebe os parâmetros SSID e PASSWORD da rede Wi-Fi via linha de comando
SSID=$1
PASSWORD=$2

# GPIO do LED principal (pino físico 13 = GPIO27)
LED_GPIO=27

# Função que configura e faz o LED piscar rapidamente (0.5s ligado, 0.5s apagado)
piscar_led_rapido() {
  if [ ! -d /sys/class/gpio/gpio$LED_GPIO ]; then
    echo $LED_GPIO > /sys/class/gpio/export
    sleep 1
  fi
  echo out > /sys/class/gpio/gpio$LED_GPIO/direction

  (
    while true; do
      echo 1 > /sys/class/gpio/gpio$LED_GPIO/value
      sleep 0.5
      echo 0 > /sys/class/gpio/gpio$LED_GPIO/value
      sleep 0.5
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

# Para e desabilita serviços do AP
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo systemctl disable hostapd
sudo systemctl disable dnsmasq

# Limpa IP fixo de wlan0
sudo sed -i '/interface wlan0/,+4d' /etc/dhcpcd.conf
sudo ip addr flush dev wlan0
sudo systemctl restart dhcpcd

# Configura nova rede Wi-Fi
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

sudo pkill wpa_supplicant 2>/dev/null || true
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

sleep 5

STATE=$(wpa_cli -i wlan0 status | grep wpa_state= | cut -d= -f2)
IP=$(ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)

SERIAL=$(awk '/Serial/ {print $3}' /proc/cpuinfo)
NEW_HOSTNAME="raspberrypi-$SERIAL"

sudo hostnamectl set-hostname "$NEW_HOSTNAME"
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname > /dev/null
sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
sudo systemctl restart avahi-daemon

if [[ "$STATE" == "COMPLETED" && -n "$IP" ]]; then
  echo "[SUCESSO] Conectado à rede '$SSID' com IP $IP"
  rm -f "$LOCKFILE"
  exit 0
else
  echo "[ERRO] Não foi possível conectar à rede Wi-Fi."
  rm -f "$LOCKFILE"
  exit 1
fi