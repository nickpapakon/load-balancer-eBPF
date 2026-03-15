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

# maps topics to VIPs (CHANGE)
vips=(
    "${VIP_A}"
    "${VIP_A}"
    "${VIP_A}"
    "${VIP_A}"
    "${VIP_B}"
    "${VIP_B}"
    "${VIP_B}"
    "${VIP_B}"
    "${VIP_B}"
    "${VIP_DEFAULT}"
)

sleep 10 # wait for network to be up and route to be added

cd utils

TOPIC_INDEX=$(( CLIENT_NUM % 10 ))

DESTINATION_IP=${MQTT_VIP}

# if we use simple Katran without mqtt_LB extension, clients should know which VIP to use for each topic, since there is no topic-based forwarding.
if [ "$SIMPLE_KATRAN" -eq 1 ]; then \
    DESTINATION_IP=${vips[$TOPIC_INDEX]}
fi


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

python3 client_pub_opts.py -H ${DESTINATION_IP} -t ${topics[$TOPIC_INDEX]} -P ${MQTT_PORT} -k ${KEEP_ALIVE} -N ${TOTAL_MESSAGES} -S ${SLEEP_TIME} -c client_${CLIENT_NUM}

# sleep so that container does not exit (if PAUSE is set to 1) and we can inspect it
if [ "$PAUSE" -eq 1 ]; then
    sleep infinity
fi
