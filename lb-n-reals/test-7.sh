#!/bin/bash

set -exo pipefail

# clear log files
rm -rf experiment-*/

# experiment with only one real
echo "1st experiment: Is .env ready ?"
sed -i 's/^ONE_REAL_ONLY=.*/ONE_REAL_ONLY=1/' .env   # Set ONE_REAL_ONLY to 1 for 1st experiment
export CONFIG_AND_OPERATE_LB=1 && export $(grep -v '^#' .env | xargs) && ./experiment.sh
mv experiment_logs/ experiment-single-broker/


# run experiment with LB
echo "2nd experiment: Is .env ready ?"
sed -i 's/^ONE_REAL_ONLY=.*/ONE_REAL_ONLY=0/' .env  # Set ONE_REAL_ONLY to 0 for 2nd experiment
export CONFIG_AND_OPERATE_LB=0 && export $(grep -v '^#' .env | xargs) && ./experiment.sh
mv experiment_logs/ experiment-LB/
