#!/bin/bash

# bpftool debug commandes

# logging of commands, exit if any cmd fails
set -euxo pipefail

bpftool prog list | grep xdp && \
bpftool prog tracelog