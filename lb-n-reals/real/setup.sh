#!/bin/bash

# real setup

# logging of commands, exit if any cmd fails
set -euxo pipefail

# static route
ip route add ${GENERAL_SUBNET} via ${GATEWAY_REAL_IP} dev eth0

# setup interfaces for ipip encapsulation
ip link add name ipip0 type ipip external
ip link set up dev ipip0
ip a a ${LOCAL_IP_FOR_IPIP}/32 dev ipip0

# the following interface type is not supported on WSL
# ip link add name ipip60 type ip6tnl external
# ip link set up dev ipip60

# Katran VIPs as loopback
# NUM env variable needed to distinguish reals
if [ -z "${NUM}" ]; then
  echo "NUM env variable is not set"
  exit 1
fi

echo "Configuring Real Server NUM=${NUM}"

ip a a ${VIP_SUBNET} dev lo
echo "Set VIPs as loopback addresses"


# remove rp_filter
for sc in $(sysctl -a | awk '/\.rp_filter/ {print $1}'); do  echo $sc ; sysctl ${sc}=0; done

# run the application
# uvicorn app:app --host 0.0.0.0 --port 8000


topics=(    
    "non_existing_topic"
    "\$share/vip_a/measurements/temperature" 
    "\$share/vip_a/measurements/temperature" 
    "\$share/vip_b/measurements/humidity" 
    "\$share/vip_b/measurements/humidity" 
    "\$share/vip_default/measurements/other"
    "\$share/vip_default/measurements/other"
)


while ! ping -c 1 -W 1 "$GATEWAY_REAL_IP" > /dev/null 2>&1; do
    echo "[client] Waiting for $GATEWAY_REAL_IP to become reachable..."
    sleep 5
done


if [ "$SHARED_SUBS" -eq 1 ]; then
  # use shared subscription to receive messages load-balanced by the broker, in the shared-subs scenario
  mosquitto_sub -h ${SHARED_SUBS_BROKER_IP} -p ${MQTT_PORT} -t ${topics[$NUM]}
else
  # operate as a real mosquitto broker, to receive messages directly from clients in the one-real-only scenario
  mosquitto -v -c /etc/mosquitto/conf.d/mosquitto.conf
fi