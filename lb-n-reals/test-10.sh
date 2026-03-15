#!/bin/bash

set -exo pipefail

COLOR_GREEN="\033[0;32m"
COLOR_OFF="\033[0m"

# clear log files
rm -rf experiment-*/
rm -rf experiment_*


sed -i 's/^SHARED_SUBS=.*/SHARED_SUBS=0/' .env
sed -i 's/^ONE_REAL_ONLY=.*/ONE_REAL_ONLY=0/' .env  

# Experiments

start_1=$(date '+%d/%m/%Y_%H:%M:%S')
echo -e "${COLOR_GREEN}  [1] Simple Katran: ${COLOR_OFF} Is .env ready ?"
sed -i 's/^SIMPLE_KATRAN=.*/SIMPLE_KATRAN=1/' .env    
sed -i 's/^ENV DISABLE_MQTT_LB=.*/ENV DISABLE_MQTT_LB=1/' katran/Dockerfile 
export CONFIG_AND_OPERATE_LB=1 && export $(grep -v '^#' .env | xargs) && ./experiment.sh
mv experiment_logs/ experiment-simple-Katran/
end_1=$(date '+%d/%m/%Y_%H:%M:%S')

sleep 50
read -p "Press Enter if ready for the next experiment ... "

start_2=$(date '+%d/%m/%Y_%H:%M:%S')
echo -e "${COLOR_GREEN}  [2] Katran-mqtt_fwd LB: ${COLOR_OFF} Is .env ready ?"
sed -i 's/^SIMPLE_KATRAN=.*/SIMPLE_KATRAN=0/' .env    
sed -i 's/^ENV DISABLE_MQTT_LB=.*/ENV DISABLE_MQTT_LB=0/' katran/Dockerfile 
export CONFIG_AND_OPERATE_LB=1 && export $(grep -v '^#' .env | xargs) && ./experiment.sh
mv experiment_logs/ experiment-mqttLB/
end_2=$(date '+%d/%m/%Y_%H:%M:%S')



# Save experiment times
# Gather all results.txt into a single file for easier analysis

echo -e "####################  Simple Katran experiment results:  ####################\n\n" > all_results.txt
echo -e "Experiment 1 (Simple Katran) start time: $start_1, end time: $end_1\n" >> all_results.txt
cat experiment-simple-Katran/results.txt >> all_results.txt
echo -e "\n\n" >> all_results.txt

echo -e "####################  Katran-mqtt_fwd LB experiment results:  ####################\n\n" >> all_results.txt
echo -e "Experiment 2 (Katran-mqtt_fwd LB) start time: $start_2, end time: $end_2\n" >> all_results.txt
cat experiment-mqttLB/results.txt >> all_results.txt
echo -e "\n\n" >> all_results.txt

mv all_results.txt experiment_results.txt

