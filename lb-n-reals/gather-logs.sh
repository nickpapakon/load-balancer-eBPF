#!/bin/bash

COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_OFF="\033[0m"

for i in {0..9}; do
    NAME="client_$i"
    LOG_FILE="experiment_logs/$NAME.log"
    echo "--- Gather logs from container $NAME ---"
    docker container logs "$NAME" > "$LOG_FILE" 2>&1 || echo -e "${COLOR_RED} Failed to get logs for container $NAME, skipping... ${COLOR_OFF}"
done

for i in {0..6}; do
    NAME="real_$i"
    LOG_FILE="experiment_logs/$NAME.log"
    echo "--- Gather logs from container $NAME ---"
    docker container logs "$NAME" > "$LOG_FILE" 2>&1 || echo -e "${COLOR_RED} Failed to get logs for container $NAME, skipping... ${COLOR_OFF}"
done