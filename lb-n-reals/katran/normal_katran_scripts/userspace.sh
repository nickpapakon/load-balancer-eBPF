#!/bin/bash

# Modify eBPF Maps from userspace
# --- VIPc - reals mappings
# --- topic -> VIPs mappings
# --- MQTT_VIP declaration

# logging of commands, exit if any cmd fails
set -euxo pipefail

SLEEP_TIME=2

echo "########################################################"
echo "Configure VIP -> reals mappings via Katran userspace gRPC client"
cd /home/simple_user/katran/example_grpc/goclient/src/katranc/main

# configure a VIP groups
./main -A -t ${VIP_A}:${MQTT_PORT}
./main -a -t ${VIP_A}:${MQTT_PORT} -r ${REAL_1_IP} -w 1
./main -a -t ${VIP_A}:${MQTT_PORT} -r ${REAL_2_IP} -w 1

./main -A -t ${VIP_B}:${MQTT_PORT} 
./main -a -t ${VIP_B}:${MQTT_PORT} -r ${REAL_3_IP} -w 1
./main -a -t ${VIP_B}:${MQTT_PORT} -r ${REAL_4_IP} -w 1

./main -A -t ${VIP_DEFAULT}:${MQTT_PORT} 
./main -a -t ${VIP_DEFAULT}:${MQTT_PORT} -r ${REAL_5_IP} -w 1
./main -a -t ${VIP_DEFAULT}:${MQTT_PORT} -r ${REAL_6_IP} -w 1

# list available services (VIP -> reals mapping)
./main -l

sleep $SLEEP_TIME

