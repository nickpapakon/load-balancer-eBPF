#!/bin/bash

# bpftool debug commandes

# logging of commands, exit if any cmd fails
set -euxo pipefail

bpftool prog list | grep xdp && \
bpftool map show name root_array && \
bpftool map dump name root_array && \
bpftool prog tracelog