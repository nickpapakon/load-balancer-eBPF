#!/bin/bash

# logging of commands, exit if any cmd fails
set -euxo pipefail

# Set up containers for monitoring
docker compose up --build -d cadvisor prometheus grafana

# Set up the servers and Load Balancer and monitoring stack
if [ "$CONFIG_AND_OPERATE_LB" -eq 1 ]; then
    docker compose up --build -d katran gateway real_[0-6]  
    echo "Waiting for containers to be up, configured and operational ..." 
    sleep 40
fi


if [ "$SHARED_SUBS" -eq 1 ]; then
    echo "Configuring MQTT broker for Shared Subscriptions experiment..."
    docker compose up --build -d gateway shared_subs_broker
    sleep 10 # wait for the shared subscription broker to be up and running
    docker compose up --build -d real_[0-6]  # reals will subscribe to the shared subscription broker
    sleep 10
    echo "MQTT broker configured for Shared Subscriptions experiment."
fi

# KATRAN / Shared Subscriptions CONFIG DONE
# EXPERIMENT STARTS HERE
# environment variables from .env should have been set
TOTAL_TIME=$(echo "$TOTAL_MESSAGES * $SLEEP_TIME" | bc)

# Run the clients to generate load (Experiments) 
docker compose up --build -d client_[0-9] 
echo "Wait enough time for the experiment to run and gather data..."
# WAIT_TIME=$(echo "$TOTAL_TIME + 30" | bc) # add some extra time to ensure all messages are published and received
# sleep $WAIT_TIME

# Wait until all client containers are down
while [ $(docker compose ps | grep client | wc -l) -gt 0 ]; do
    echo "Waiting for client containers to stop..."
    sleep 5
done
# while docker compose ps --status running | grep -qE 'client_[0-9]'; do
#     echo "Waiting for client containers to stop..."
#     sleep 5
# done

sleep 10 # add some extra time to ensure all messages are published and received

# Gather logs from all containers, parse them and save the results along with environment variables for reproducibility
rm -f experiment_logs/*
mkdir -p experiment_logs/
chmod +x gather-logs.sh
./gather-logs.sh

source ../.venv/bin/activate
python parse_logs.py --reals 6 --log_dir experiment_logs/ | sort > experiment_logs/results.txt
cp .env experiment_logs/

echo "Experiment completed. Logs and environment variables have been saved in the experiment_logs/ directory."