#!/bin/bash

# shared_subs_broker setup

# logging of commands, exit if any cmd fails
set -euxo pipefail

# static route
ip route add ${GENERAL_SUBNET} via ${GATEWAY_SHARED_SUBS_BROKER_IP} dev eth0

while ! ping -c 1 -W 1 "$GATEWAY_SHARED_SUBS_BROKER_IP" > /dev/null 2>&1; do
    echo "[client] Waiting for $GATEWAY_SHARED_SUBS_BROKER_IP to become reachable..."
    sleep 5
done

# run broker (MQTT v5)
mosquitto -v -c /etc/mosquitto/conf.d/mosquitto.conf
