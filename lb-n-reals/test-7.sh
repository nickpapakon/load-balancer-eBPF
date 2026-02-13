#!/bin/bash

set -exo pipefail

echo "1st experiment: Is .env ready ?"
read escape_char
export CONFIG_AND_OPERATE_LB=1 && ./experiment.sh
mv experiment_logs/ experiment-single-broker/

# erase the ONE_REAL_ONLY=1 env variable and run experiment with LB
echo "2nd experiment: Is .env ready ?"
read escape_char
# clear container logs
docker compose up --build -d real_[1-6]
export CONFIG_AND_OPERATE_LB=0 && ./experiment.sh
mv experiment_logs/ experiment-LB/

# change client IPs in .env     (and close docker real containers to clear logs by hand)
echo "3rd experiment: Is .env ready ?"
read escape_char
# clear container logs
docker compose up --build -d real_[1-6]
export CONFIG_AND_OPERATE_LB=0 && ./experiment.sh
mv experiment_logs/ experiment-after-change-client-ip/