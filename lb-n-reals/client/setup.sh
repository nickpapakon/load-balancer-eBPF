#!/bin/bash

# client setup

# logging of commands, exit if any cmd fails
set -euxo pipefail

# static route
ip route add ${GENERAL_SUBNET} via ${GATEWAY_CLIENT_IP} dev eth0



# TOPICS published by clients 1,2,3,4,5,6
topics=(    
    "measurements/temperature" 
    "measurements/temperature" 
    "measurements/humidity" 
    "measurements/humidity" 
    "measurements/humidity" 
    "measurements/other"
)

cd utils
python3 client_pub_opts.py -H ${MQTT_VIP} -t ${topics[$CLIENT_NUM - 1]} -P ${MQTT_PORT} -k ${KEEP_ALIVE} -N ${TOTAL_MESSAGES} -S ${SLEEP_TIME} -c client_${CLIENT_NUM}

# sleep so that container does not exit
# sleep infinity
