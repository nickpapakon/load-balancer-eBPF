#!/bin/bash

# logging of commands, exit if any cmd fails
set -euxo pipefail

# run katran_server_grpc to load bpf prog (balancer_ingress)
cd /home/simple_user/katran/_build
sudo ./build/example_grpc/katran_server_grpc -balancer_prog ./deps/bpfprog/bpf/balancer.bpf.o  -forwarding_cores=0 -hc_forwarding=false -lru_size=10000 -default_mac ${GATEWAY_KATRAN_MAC}  -intf ${KATRAN_INTERFACE} &

cd /home/simple_user/normal_katran_scripts
echo "Waiting for katran_server_grpc to start and load the bpf progs..."
sleep 15
./userspace.sh && ./debug.sh
