#!/bin/bash

COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_OFF="\033[0m"

for i in {0..9}; do
    for container_type in real client; do 
        NAME="${container_type}_$i"
        LOG_FILE="experiment_logs/$NAME.log"
        echo "--- Gather logs from container $NAME ---"

        # Export logs (combining stdout and stderr)
        docker container logs "$NAME" > "$LOG_FILE" 2>&1 || echo -e "${COLOR_RED} Failed to get logs for container $NAME, skipping... ${COLOR_OFF}"
    done 
done