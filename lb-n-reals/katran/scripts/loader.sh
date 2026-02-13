#!/bin/bash

# xdp root prog installation and 
# run katran_server_grpc to load bpf progs (mqtt_fwd + balancer_ingress)

# logging of commands, exit if any cmd fails
set -euxo pipefail

cd /home/simple_user/katran
./install_xdproot.sh

cd /home/simple_user/katran/_build
sudo ./build/example_grpc/katran_server_grpc -balancer_prog ./deps/bpfprog/bpf/balancer.bpf.o  -forwarding_cores=0 -hc_forwarding=false -lru_size=10000 -default_mac ${GATEWAY_KATRAN_MAC} -map_path /sys/fs/bpf/jmp_${KATRAN_INTERFACE} -prog_pos=2 -mqtt_fwd true -mqtt_topic_based_fwd_prog ./deps/bpfprog/bpf/mqtt_topic_based_fwd.bpf.o -mqtt_prog_pos 1 -intf ${KATRAN_INTERFACE} &

cd /home/simple_user/scripts
echo "Waiting for katran_server_grpc to start and load the bpf progs..."
sleep 10
./userspace.sh && ./debug.sh
