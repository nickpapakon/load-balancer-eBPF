#!/bin/bash

# client setup

# logging of commands, exit if any cmd fails
set -exo pipefail

# static route
ip route add ${GENERAL_SUBNET} via ${GATEWAY_CLIENT_IP} dev eth0



# TOPICS: 4 temperature, 5 humidity, 1 other
# Each client publishes topics[$CLIENT_NUM % 10]
topics=(
    "measurements/temperature" 
    "measurements/temperature" 
    "measurements/temperature" 
    "measurements/temperature" 
    "measurements/humidity" 
    "measurements/humidity" 
    "measurements/humidity" 
    "measurements/humidity" 
    "measurements/humidity"
    "measurements/other"
)

sleep 10 # wait for network to be up and route to be added

cd utils

DESTINATION_IP=${MQTT_VIP}

if [ "$ONE_REAL_ONLY" -eq 1 ]; then
    DESTINATION_IP=${REAL_0_IP}
fi

if [ "$SHARED_SUBS" -eq 1 ]; then
    DESTINATION_IP=${SHARED_SUBS_BROKER_IP}
fi

while ! ping -c 1 -W 1 "$GATEWAY_CLIENT_IP" > /dev/null 2>&1; do
    echo "[client] Waiting for $GATEWAY_CLIENT_IP to become reachable..."
    sleep 5
done

TOPIC_INDEX=$(( CLIENT_NUM % 10 ))
python3 client_pub_opts.py -H ${DESTINATION_IP} -t ${topics[$TOPIC_INDEX]} -P ${MQTT_PORT} -k ${KEEP_ALIVE} -N ${TOTAL_MESSAGES} -S ${SLEEP_TIME} -c client_${CLIENT_NUM}

# sleep so that container does not exit (if PAUSE is set to 1) and we can inspect it
if [ "$PAUSE" -eq 1 ]; then
    sleep infinity
fi
