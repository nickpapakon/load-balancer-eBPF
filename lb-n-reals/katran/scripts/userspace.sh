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





echo "########################################################"
echo "Configure topic -> VIP mappings via user_bpfmap client"
# Update eBPF map from userspace  [topic -> VIP (group of responsible services)]
export MAP_ID=$(bpftool map list | grep mqtt_topic | awk -F':' '{ print $1 }') && \
bpftool map show id $MAP_ID  && \
cd /home/simple_user/xdp-tutorial/basic00-update-map  && \
./user_bpfmap $MAP_ID measurements/temperature $VIP_A  && \
./user_bpfmap $MAP_ID measurements/humidity $VIP_B  && \
bpftool map dump id $MAP_ID

sleep $SLEEP_TIME





echo "########################################################"
echo "Configure MQTT_VIP using bpftool"
export MAP_ID=$(bpftool map list | grep mqtt_service | awk -F':' '{ print $1 }')
bpftool map show id $MAP_ID
# MQTT_VIP=a.b.c.d
a=$(echo $MQTT_VIP | awk -F'.' '{ print $1  }')
b=$(echo $MQTT_VIP | awk -F'.' '{ print $2  }')
c=$(echo $MQTT_VIP | awk -F'.' '{ print $3  }')
d=$(echo $MQTT_VIP | awk -F'.' '{ print $4  }')
bpftool map update id $MAP_ID key 0 0 0 0 value $a $b $c $d 0 0 0 0 0 0 0 0 0 0 0 0
bpftool map dump id $MAP_ID

sleep $SLEEP_TIME