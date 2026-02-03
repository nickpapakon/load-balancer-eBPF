#!/bin/bash

for i in {1..6}; do
    for container_type in real client; do 
        NAME="${container_type}_$i"
        LOG_FILE="experiment_logs/$NAME.log"
        echo "--- Gather logs from container $NAME ---"

        # Export logs (combining stdout and stderr)
        docker container logs "$NAME" > "$LOG_FILE" 2>&1
    done 
done