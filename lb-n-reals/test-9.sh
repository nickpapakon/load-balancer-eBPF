#!/bin/bash

set -exo pipefail

COLOR_GREEN="\033[0;32m"
COLOR_OFF="\033[0m"

# clear log files
rm -rf experiment-*/

# Experiments

date '+%d/%m/%Y_%H:%M:%S'
echo -e "${COLOR_GREEN}  [1] Single broker experiment: ${COLOR_OFF} Is .env ready ?"
sed -i 's/^SHARED_SUBS=.*/SHARED_SUBS=0/' .env      # ensure SHARED_SUBS is 0 for 1st and 2nd experiments  
sed -i 's/^ONE_REAL_ONLY=.*/ONE_REAL_ONLY=1/' .env   # Set ONE_REAL_ONLY to 1 for 1st experiment
export CONFIG_AND_OPERATE_LB=1 && export $(grep -v '^#' .env | xargs) && ./experiment.sh
mv experiment_logs/ experiment-single-broker/
sleep 180


date '+%d/%m/%Y_%H:%M:%S'
echo -e "${COLOR_GREEN}  [2] Katran-mqtt_fwd LB experiment: ${COLOR_OFF} Is .env ready ?"
sed -i 's/^SHARED_SUBS=.*/SHARED_SUBS=0/' .env      # ensure SHARED_SUBS is 0 for 1st and 2nd experiments  
sed -i 's/^ONE_REAL_ONLY=.*/ONE_REAL_ONLY=0/' .env  # Set ONE_REAL_ONLY to 0 for 2nd experiment
export CONFIG_AND_OPERATE_LB=0 && export $(grep -v '^#' .env | xargs) && ./experiment.sh
mv experiment_logs/ experiment-LB/
sleep 180

date '+%d/%m/%Y_%H:%M:%S'
echo -e "${COLOR_GREEN}  [3]: Shared Subscription broker experiment: ${COLOR_OFF} Is .env ready ?"
sed -i 's/^ONE_REAL_ONLY=.*/ONE_REAL_ONLY=0/' .env  
sed -i 's/^SHARED_SUBS=.*/SHARED_SUBS=1/' .env # set SHARED_SUBS to 1 for Shared Subscription experiment
export CONFIG_AND_OPERATE_LB=0 && export $(grep -v '^#' .env | xargs) && ./experiment.sh
mv experiment_logs/ experiment-shared-subscriptions/
