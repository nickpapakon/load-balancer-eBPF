TARGET = xdp

BPF_OBJ = _build/deps/bpfprog/bpf/mqtt_topic_based_fwd.bpf.o
C_FILE = katran/lib/bpf/mqtt_topic_based_fwd.bpf.c

xdp: load 
	bpftool net attach xdpgeneric pinned /sys/fs/bpf/$(TARGET) dev eth0 

load: detach_and_unload compile_bpf
	bpftool net detach xdpgeneric dev eth0
	rm -f /sys/fs/bpf/$(TARGET)
	bpftool prog load $(BPF_OBJ) /sys/fs/bpf/$(TARGET)
	
compile_bpf: $(BPF_OBJ)
	echo "BPF program compiled: $(BPF_OBJ)"


obj := .

DEBUGBPF = -DDEBUG
DEBUGFLAGS = -O0 -g -Wall
PFLAGS = $(DEBUGFLAGS)
CLANG ?= clang
LLC ?= llc

INCLUDEFLAGS = -I$(obj)/usr/include \
	       -I$(obj)/katran/lib/bpf/linus_includes \
		   -I$(obj)/include \
	       -I$(obj)


$(BPF_OBJ): $(C_FILE)
	$(CLANG) $(INCLUDEFLAGS) $(EXTRA_CFLAGS) \
	$(DEBUGBPF) -D__KERNEL__ -Wno-unused-value -Wno-pointer-sign \
		-Wno-compare-distinct-pointer-types \
		-O2 -emit-llvm -c -g $< -o -| $(LLC) -march=bpf -filetype=obj -o $@

clean: detach_and_unload
	rm $(BPF_OBJ)

detach_and_unload:
	bpftool net detach xdpgeneric dev eth0
	rm -f /sys/fs/bpf/$(TARGET)
	

