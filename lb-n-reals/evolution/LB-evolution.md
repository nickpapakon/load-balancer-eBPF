# MQTT Topic Based Load Balancing

Imagine of an MQTT cluster containing brokers and clients were these rules are satisfied:
- Only MQTT publish messages are delivered
- Each client sends messages of only one topic (e.g. Many clients can publish to topic `temperature`, but there cannot be any client that publishes to both `temperature` and `humidity` topics)

We want to load-balance the MQTT publish messages to brokers (e.g. A,B,C,D,E,F,G,H) based on their topic.

| topic    | Broker  |
| -------- | ------- |
| apples   | A/B/C   |
| oranges  | D/E     |
| lemons   | F/G/H   |

For example, an MQTT publish message that has topic `apples` should be forwarded to one broker between broker A, broker B, broker C.

Grouping of these IPs can be done by utilizing an existing project `Katran`, that proposes VIPs. So VIP_I can stand for A/B/C, VIP_II for D/E and so on. Load balancing between brokers of a certain VIP is also done by Katran project, so here we will emphasize on deciding the VIP that corresponds to a certain MQTT communication (including TCP 3WHS, MQTT CONNECT/CONNACK, MQTT PUBLISH and MQTT DISCONNECT REQ). Katran also handles the forwarding of a flow of messages (identifies that from the 5-tuple of proto, ports, ip-addrs) to be done to the same real/broker.

As each client sends messages only of one topic, we can predict the topic that the client wants to send based on the client IP. In fact, Load Balancer can maintain a map that correlates client IPs (keys) with the last topic that was sent by them (value).
However, whenever client sends the first packet or whenever client changes IP, there is no correct corresponding match in this Map and the TCP SYN, ACK and MQTT CONNECT packets may be delivered to a non-responsible VIP (these packets do not contain the MQTT topic - but should be forwarded to the correct VIP). When the MQTT publish packet arrives Load Balancer understands that the previous segments that initiated the connection were not properly forwarded (What to do with this PUBLISH packet is still a **TODO**). Load Balancer updates the Map to correctly identify the last topic published by this client IP (so the next packets by this IP will bw correctly forwarded to the responsible VIP). 

## Test 1

### Limitations

In order to present a simple first version some **constraints** were adopted.
- Fixed Topic Length (`FIXED_TOPIC_LENGTH 8`): eBPF Verifier complains when `memcpy` has a length parameter value that is not a compile-time constant
TODO in next test to remove this limitation (and ensure that variable topic length can be used - MQTT topic length can vary to up to 2^16 - 1 )
- Only one client used: This is a limitation of the scratch LB.
However this should not be a problem, as we tested the circumstance that this client changes IP and continues publishing messages
- IPv6 packets are not handled: If we need to run MQTT and TCP over IPv6, modifications are needed (however eBPF Maps and structs already contain the field for the ipv6 address in a union with ipv4 address)
- Suppose that we use the classic MQTT over TCP
- Whenever the client IP changes the first MQTT PUBLISH message is lost (see description below)

### MQTT-Topic based forwarding logic 

In this test:
We want to load balance MQTT PUBLISH messages based on topics
| topic        | Broker  |
| ------------ | ------- |
| sensors/     | real_1  |
| other topics | real_2  |

### scratch LB eBPF Maps

The `lb_from_scratch` container is a simple Load Balancer that supports only one client (see limitations above) and runs an eBPF program that manipulates the BPF maps:
- eBPF Map `mqtt_topic_to_vip`: topic `sensors/` key corresponds to VIP that maps to broker `real_1`
- eBPF Map `client_ips`: client IP      (This map is used because scratch LB is silly - it does not learn client IPs on its own)
                                      (In case of Katran we won't need this Map because Reals send the packets directly to the clients, so Katran receives Packets only from the clients and won't send anything to them)
- eBPF Map `mqtt_client_ip_to_topic` is only modified by the kernel eBPF program. Whenever a MQTT PUBLISH packet is received, this map is updated (key `client src IP` -> value `topic`) so  we maintain the last topic that was published by each client IP and the next time a packet arrives the LB can do a correct prediction of the topic based on src IP and forward to the responsible IP.


### Test Procedure

- `Phase 1`: Client has initially the IP `10.1.1.107`. Sends 3 MQTT PUBLISH messages to the MQTT VIP
The first one **fails** to be delivered (client IP does not exist yet as key in the eBPF map that predicts topics)
The next two are successfully delivered to the correct MQTT real server
Let's say that client IP changes to 10.1.1.102
- `Phase 2`: After the change of the client IP to `10.1.1.102`. Client sends 3 MQTT PUBLISH messages as before.
Again the first PUBLISH message **fails** to be delivered (new client IP not in BPF map)
The next two are successfully delivered to the correct MQTT real server

Logs and a capture are stored in `test-1/`.

### Commands

- set `CLIENT_IP=10.1.1.107` in the `.env` file

- Docker compose of `client`, `lb_from_scratch`, `real_1`, `real_2`, `gateway` containers 

- 4 terminals open were you will connect to containers `docker exec -it <container_name> sh`: `client_SH`, `lb_SH_1`, `lb_SH_2`, `gateway_SH`

- In `lb_SH_1`, check the trace pipe (where `bpf_printk` commands write their output)
```bash
bpftool prog tracelog
```

- Gateway captures packets on the interface that looks to the `lb_from_scratch`. So, in `gateway_SH`
```bash
tcpdump -n -i eth3 -nnXXtttt -w /tmp/gateway_eth3_capture.pcap -C 3 -G 600 
```

- In `lb_SH_2`, update the eBPF Map `mqtt_topic_to_vip` so that depicts that the responsible broker for topic `sensors/` is  `real_1` and instruct the `client_ips` Map with the client IP
```bash
# LB from Scratch - Update eBPF map from userspace  [topic -> responsible broker]
export MAP_ID=$(bpftool map list | grep mqtt_topic | awk -F':' '{ print $1 }')
bpftool map show id $MAP_ID
cd xdp-tutorial/basic00-update-map
./user_bpfmap $MAP_ID sensors/ $REAL_1_IP
bpftool map dump id $MAP_ID

# eBPF Map that will store [key:1 -> CLIENT_IP]
export MAP_ID=$(bpftool map list | grep client_ips | awk -F':' '{ print $1 }')
bpftool map show id $MAP_ID
# CLIENT_IP=10.1.1.107
bpftool map update id $MAP_ID key 1 0 0 0 value 10 1 1 107 0 0 0 0 0 0 0 0 0 0 0 0
bpftool map dump id $MAP_ID
```

- In `client_SH`, make the MQTT publish messages
```bash
cd utils
./massive_pub.sh
# How many times would you like to Do MQTT PUB? 3
# Enter the QOS level (0, 1, or 2): 0
```

- (change client IP): set `CLIENT_IP=10.1.1.102` in the `.env` file

- Docker compose of `client` AGAIN.

- In `lb_SH_2`,  instruct the `client_ips` Map with the NEW client IP
```bash
# eBPF Map that will store [key:1 -> new CLIENT_IP]
export MAP_ID=$(bpftool map list | grep client_ips | awk -F':' '{ print $1 }')
bpftool map show id $MAP_ID
# CLIENT_IP=10.1.1.102
bpftool map update id $MAP_ID key 1 0 0 0 value 10 1 1 102 0 0 0 0 0 0 0 0 0 0 0 0
bpftool map dump id $MAP_ID
```

- In `client_SH`, make the MQTT publish messages (again)... (Now client publishes from the new IP)
- Stop and Copy the trace pipe logs from `lb_SH_1`
- Stop and save the capture from `gateway_SH`




## Test 2

### Limitations - Modifications since previous test

Feature:
- Variable MQTT Topic Length up to 80 characters is supported in this version

The rest limitations have not been addressed yet.

### MQTT-Topic based forwarding logic 

| topic        | Broker  |
| ------------ | ------- |
| sensors/     | real_1  |
| living-room/ | real_2  |
| other topics | real_3  |

### Test Procedure
- Publish 3 times to a big 80-char topic that has broker_1 as the responsible server. The first MQTT PUBLISH will fail (the TCP 3WHS and MQTT connect were forwarded to real_3 as there was no predicted topic). The next two PUBLISH messages will be successfully forwarded to real_1.
- Publish 3 times to `sensors/` so that the PUBLISH messages go to `real_1`. Now all 3 messages will succeed. In fact, the first one is lucky due to the fact that the previous topic that was sent by the client IP was also intended to be forwarded to real_1 (so although predicted_topic is different - the 3WHS has luckily been done with the right broker - real_1)
- Publish 3 times to `living-room/` so that the PUBLISH messages go to `real_2`. Here the first PUBLISH will fail (TCP 3WHS with real_1) but the next ones will properly be sent to real_2

### Commands


- Docker compose of `client`, `lb_from_scratch`, `real_1`, `real_2`, `gateway` containers 

- 4 terminals open were you will connect to containers `docker exec -it <container_name> sh`: `client_SH`, `lb_SH_1`, `lb_SH_2`, `gateway_SH`

- In `lb_SH_1`, check the trace pipe (where `bpf_printk` commands write their output)
```bash
bpftool prog tracelog
```

- Gateway captures packets on the interface that looks to the `lb_from_scratch`. So, in `gateway_SH`
```bash
tcpdump -n -i eth3 -nnXXtttt -w /tmp/gateway_eth3_capture.pcap -C 3 -G 600 
```


```bash
# LB from Scratch - Update eBPF map from userspace  [topic -> responsible broker]
export MAP_ID=$(bpftool map list | grep mqtt_topic | awk -F':' '{ print $1 }')
bpftool map show id $MAP_ID
cd xdp-tutorial/basic00-update-map
./user_bpfmap $MAP_ID aabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddee $REAL_1_IP
./user_bpfmap $MAP_ID qqwweerrttqqwweerrttqqwweerrttqqwweerrttqqwweerrttqqwweerrttqqwweerrttqqwweerrtt $REAL_2_IP
./user_bpfmap $MAP_ID sensors/ $REAL_1_IP
./user_bpfmap $MAP_ID living-room/ $REAL_2_IP
bpftool map dump id $MAP_ID


# client
# expected to be fwd to real 1
# 3 times
mosquitto_pub -h ${SCRATCH_LB_IP}  -p ${MQTT_PORT} -m "motor temp, current, ..." -t aabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddee --qos 0

# 3 times
mosquitto_pub -h ${SCRATCH_LB_IP}  -p ${MQTT_PORT} -m "motor temp, current, ..." -t sensors/ --qos 0

#expected to be fwd to real 2
# 3 times
mosquitto_pub -h ${SCRATCH_LB_IP}  -p ${MQTT_PORT} -m "motor temp, current, ..." -t living-room/ --qos 0
```
- Stop and Copy the trace pipe logs from `lb_SH_1`
- Stop and save the capture from `gateway_SH`


- If you try `netstat -tn` for the `test-2/test-3` version (exactly after the first publish command that will not succed), 
you will get a tcp active connection that has non-zero Send-Q and is in state FIN_WAIT1. Connection has not closed by client even if client received a TCP RST from the real.

```bash
# netstat -tn
Active Internet connections (w/o servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State      
tcp        0     39 10.1.1.102:47764        10.1.5.102:1883         FIN_WAIT1
```

<!--
python3 client_pub_opts.py -H 127.0.0.1 -t motor/ -P 1883 -k 5 -N 20 -S 1

mosquitto_pub -h ${SCRATCH_LB_IP}  -p ${MQTT_PORT} -m "" -t aabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddeeaabbccddee --qos 0
-->

## Test 3

### Test Procedure

No modifications done on Load Balancer. 
- Send multiple MQTT PUBLISH messages of the same topic under a single TCP connection using a python `paho.mqtt` client
- All of them fail (as TCP 3WHS has been sent to a non-responsible server and the PUBLISH messages are sent to another server - the responsible one)
- Repeat the procedure - rerun the python client that sends multiple MQTT PUBLISH messages with the same topic 
- Now a new TCP connection is used and thus the messages are all properly forwarded to the same responsible broker.

### Command

```bash
# keep-alive of 3 sec
# send 6 messages
# sleep time between them: 1 sec
python3 client_pub_opts.py -H ${SCRATCH_LB_IP} -t living-room/ -P ${MQTT_PORT} -k 3 -N 6 -S 1

# first time we expect that no message will be sent correctly to the right browser (TCP 3WHS and connect with real_3 - though message intended for real_2)

# second time we run the command, as a new TCP 3WHS happens to the appropriate broker, all MQTT PUBLISH messages are correctly delivered to broker real_2
```


## Test 4

### Limitations

- variable topic len up to 8 chars
- 1st mqtt pub message lost every time the client changes IP, loss continues until client re-connects
- no IPv6 handling
- every packet destined to MQTT-port (1883) is handled in this way (idea: use the configurable `MQTT_VIP` to discriminate MQTT service)

### eBPF Programs

This version consists of multiple bpf (xdp) programs that are tail-called using `bpf_tail_call`.
- `xdp_root`: The XDP program that is attached to the network interface and makes a tail call to `root_array[1]` program
- `root_array[1]`: My XDP program `mqtt_fwd` that performs the MQTT topic-based forwarding logic. If the received packet is destined to the `MQTT_PORT = 1883` then this program **changes the destination IP to a VIP** that represents a group of reals/brokers. The group of reals is selected **based on the (predicted/actual) MQTT topic** that (would be / is) used in the communication (check previous explanations for this logic). At the end, the program makes tail call to `root_array[2]` either there was a modification in the frame or not.
- `root_array[2]`: here Katran `balancer_ingress` xdp program is registered so that takes responsibility for the load balancing task. Katran looks at the destination IP of the packet and selects the real-broker to which the frame will be forwarded based on the VIP - reals mapping (from eBPF Maps that have been modified from userspace). 5-tuple (proto, src IP, src port, dst IP, dst port) is also considered in order to forward packets from the same session to the same broker. While making the encapsulated IPIP packet, the old ip header destination address (which was modified by `mqtt_fwd` program) changes to the `MQTT_VIP` value (stored in `mqtt_service_vips` eBPF map modified by userspace) which is meant to be used from the client for the communication with LB (checksum also needs to be updated).



### Topic to VIP mapping

| topic        | VIP         |
| ------------ | ----------- |
| `sensor/a`   | VIP_A       |
| `sensor/b`   | VIP_B       |
| other topics | VIP_DEFAULT |

### VIP to reals mapping 

| VIP         | Reals (brokers)  |
| ----------- | ---------------- |
| VIP_A       | 1                |
| VIP_B       | 2                |
| VIP_DEFAULT | 3                |


### Commands

Open three terminals `termA`, `termB`, `termC` to interact with Katran container
```bash
docker exec -it katran sh
```

- On `termA`, Install xdproot and Run Katran Server-Loader.
```bash
cd /home/simple_user/katran
./install_xdproot.sh
```

```bash
cd /home/simple_user/katran/_build
sudo ./build/example_grpc/katran_server_grpc -balancer_prog ./deps/bpfprog/bpf/balancer.bpf.o  -forwarding_cores=0 -hc_forwarding=false -lru_size=10000 -default_mac ${GATEWAY_KATRAN_MAC} -map_path /sys/fs/bpf/jmp_${KATRAN_INTERFACE} -prog_pos=2 -mqtt_fwd true -mqtt_topic_based_fwd_prog ./deps/bpfprog/bpf/mqtt_topic_based_fwd.bpf.o -mqtt_prog_pos 1 -intf ${KATRAN_INTERFACE}
```

- After the previous commands, you should see 3 xdp programs loaded in bpf/kernel (`xdp_root`, `mqtt_fwd`, `balancer_ingress`). You should also see a bpf Map `root_array` that contains the mapping `1 -> mqtt_fwd, 2 -> balancer_ingress` and is used for the `bpf_tail_call` calls. You can inspect these with the bpftool commands on `termB` (run the final command also to inspect the `bpf_printk` logs from the bpf programs):
```bash
bpftool prog list | grep xdp && \
bpftool map show name root_array && \
bpftool map dump name root_array && \
bpftool prog tracelog
```

<!--
Lookup / Disable mqtt_fwd program
bpftool map lookup name root_array key 1 0 0 0
bpftool map delete  name root_array key 1 0 0 0
-->

- On `termC`, run commands for the go client to configure VIPs and reals for Katran
```bash
cd /home/simple_user/katran/example_grpc/goclient/src/katranc/main

# configure a VIP groups
./main -A -t ${VIP_A}:${MQTT_PORT}
./main -a -t ${VIP_A}:${MQTT_PORT} -r ${REAL_1_IP} -w 1
./main -A -t ${VIP_B}:${MQTT_PORT} 
./main -a -t ${VIP_B}:${MQTT_PORT} -r ${REAL_2_IP} -w 1
./main -A -t ${VIP_DEFAULT}:${MQTT_PORT} 
./main -a -t ${VIP_DEFAULT}:${MQTT_PORT} -r ${REAL_3_IP} -w 1

# list available services (VIP -> reals mapping)
./main -l
```

- On `termC`, configure the mapping of topics to VIPs for `mqtt_fwd` program
```bash
# Update eBPF map from userspace  [topic -> VIP (group of responsible services)]
export MAP_ID=$(bpftool map list | grep mqtt_topic | awk -F':' '{ print $1 }') && \
bpftool map show id $MAP_ID  && \
cd /home/simple_user/xdp-tutorial/basic00-update-map  && \
./user_bpfmap $MAP_ID sensor/a $VIP_A  && \
./user_bpfmap $MAP_ID sensor/b $VIP_B  && \
bpftool map dump id $MAP_ID
```

- On `termC`, configure the general mqtt VIP that the client uses, so that `balancer_ingress` changes the destination IP to this one instead of the specific VIP that was given by the `mqtt_fwd` program
```bash
export MAP_ID=$(bpftool map list | grep mqtt_service | awk -F':' '{ print $1 }')
bpftool map show id $MAP_ID
# MQTT_VIP=10.1.50.200
# echo $MQTT_VIP | awk -F'.' '{ print $1  }'
bpftool map update id $MAP_ID key 0 0 0 0 value 10 1 50 200 0 0 0 0 0 0 0 0 0 0 0 0
bpftool map dump id $MAP_ID
```

- **Gateway**: Open terminal and start capturing on  `any` interfaces
```bash
docker exec -it gateway sh

tcpdump -n -i any -nnXXtttt -w /tmp/gateway_any_capture.pcap -C 3 -G 600 
```

- **Client**: Open another terminal and Then try to publish messages to mqtt_LB/katran:
```bash
docker exec -it client sh

# run the following multiple (3+) times
mosquitto_pub -h ${MQTT_VIP} -t sensor -p ${MQTT_PORT} -m "motor temp, current, ..."
# Expectations (all times sent to VIP_DEFAULT group - no predicted topic / no matching topic-VIP mapping found)
#               in our case goes always to real 3
```

- Stop and collect the captures on gateway containers

- Collect logs from `bpftool prog tracelog` running on `termB`


## Test 5

Minor fixes concerning a bug and better logging.
Test shows the behavior of `mqtt_LB` when receiving many MQTT messages with different topics
As expected the first packet with a topic that is meant to be sent to a different VIP group does not properly arrive on any of the responsible brokers due to false topic prediction. All other commands are the same. Hopefully,

- In this version, instead of manually pasting the commands you can use the `scripts/` provided in `/home/simple_user` of katran container
```bash
docker exec -it katran sh

# termA
./scripts/loader.sh
# termB
./scripts/debug.sh
# termC
./scripts/userspace.sh
```

- **Gateway**: Open terminal and start capturing on  `any` interfaces
```bash
docker exec -it gateway sh

tcpdump -n -i any -nnXXtttt -w /tmp/gateway_any_capture.pcap -C 3 -G 600 
```

- **Client**: Open another terminal and Then try to publish messages to mqtt_LB/katran:
```bash
# run the following multiple (3+) times
mosquitto_pub -h ${MQTT_VIP} -t sensor/a -p ${MQTT_PORT} -m "motor temp, current, ..."
# Expectations (see docker container logs):
# 1st time:  
#       Message is possibly NOT PUBLISHED to any broker (connection done with a broker from the VIP_DEFAULT VIP group) - Here real-3
# Next times: 
#       Message is successfully published to a responsible (member of VIP_A) broker  - Here real-1


# repeat procedure for sensor/b -> VIP_B
mosquitto_pub -h ${MQTT_VIP} -t sensor/b -p ${MQTT_PORT} -m "motor temp, current, ..."
# Expectations (see docker container logs):
# 1st time:  
#       Message is NOT PUBLISHED to any broker (connection done with a broker from the VIP_A - Here real-1 -
#       due to the fact that mqtt_fwd prog makes prediction of topic based on the client IP - 
#       Here predicted topic: sensor/a   that differs from the actual)
# Next times: 
#       Message is successfully published to a responsible (member of VIP_B) broker  - Here real-2  
#       (as the client-IP to mqtt topic mapping has been updated from the previous message)
```

- Stop and collect the captures on gateway containers

- Collect logs from `bpftool prog tracelog` running on `termB`

- (Optional) You can make just a single command that publishes an MQTT message (whose topic is expected to be mis-predicted) and notice that the `TCP RST` that comes from the real/broker and then the client remains silent (closes the TCP connection due to reset). This could be observed also in the capture, as the next `TCP SYN` after a `TCP RST` is after 3 seconds (generated by a user command - and not automatically generated). Short proof of the reset of the connection: if you immediately run `ss -tin` or `netstat -tn` after the publish command you won't see anything. 

- (Optional) (not captured) Similar results to Test 3 are produced by the following procedure
```bash
cd utils
python3 client_pub_opts.py -H ${MQTT_VIP} -t sensor -P ${MQTT_PORT} -k 3 -N 6 -S 1
```


## Test 6

In this test, we introduce more clients and reals.
- Each client publishes to a specific topic (many clients may publish to the same topic though)
- Each MQTT-topic may be intended for  many reals. 
- Each message will be received by only one of these reals.

### Clients publish to topics

| client | topic                      |
| ------ | -------------------------- |
|  1,2   | `measurements/temperature` |
| 3,4,5  | `measurements/humidity`    |
|   6    | `measurements/other`       |


### Topic to VIP  &  VIP to reals   mappings

| topic                      | VIP         | Reals (brokers)  |
| ---------------------------| ----------- | ---------------- |
| `measurements/temperature` | VIP_A       | 1,2              |
| `measurements/humidity`    | VIP_B       | 3,4              |
| other topics               | VIP_DEFAULT | 5,6              |


### Commands

- Start `katran` and `gateway` containers. Configure by userspace the BPF maps of katran using `scripts/userspace.sh`
```bash
docker compose up --build -d katran gateway real_[1-6]
# ensure all containers are up (retries may be needed for gateway)

docker exec -it katran sh -c "scripts/userspace.sh && scripts/debug.sh"
# wait and notice logs until the above script reaches the last command `bpftool prog tracelog`
```

- Start `clients` (setup script has been modified so that clients begin MQTT publishing 100 messages without further action) and notice **CPU, memory usage, NET I/O**  of `reals` containers during the test (be ready publishing-test lasts only some seconds and no longer than minute depending the `TOTAL_MESSAGES` and `SLEEP_TIME` env variables). Maybe, later, use grafana to monitor them
```bash
docker compose up --build -d client_[1-6]

# notice CPU, MEM, NET I/O
docker stats --no-stream 
```

- Gather experiment container logs and collect manually the `docker stats` and `bpftool prog tracelog` logs (then parse them with regex)
```bash
mkdir experiment_logs/
chmod +x gather-logs.sh
./gather-logs.sh
```

### Experiment Observations

```bash
user$[~/load-balancer-eBPF/lb-n-reals]
└──> python parse_logs.py --reals 6 --log_dir ./evolution/test-6
Client 2 sent 99 PUBLISH messages to real 1
Client 1 sent 99 PUBLISH messages to real 1
Client 4 sent 99 PUBLISH messages to real 4
Client 5 sent 99 PUBLISH messages to real 4
Client 3 sent 99 PUBLISH messages to real 4
Client 6 sent 100 PUBLISH messages to real 6
```

- We noticed that packets from the same client go to the same real/broker due to the 5-tuple based LB,
When there is keep-alive setting enabled, connection remains alive between client and broker and is verified through PINGREQ/PINGRESP periodically, so the same src port is used for MQTT communication and thus the 5-tuple remains the same and LB forwards to the same real/broker.
- When there is a faulty prediction concerning the topic, the first MQTT PUBLISH message is lost


### TODOs

- Parse logs
- Compare with PUBLISH to a single broker
- Grafana monitoring
- Client in sleep mode for debug purposes
- Other manner to measure using eBPF
- BPF_PRINTs should be removed for performance
- Katran performance
- Comparison with Shared Subscriptions
- LPM eBPF Maps for support of wildcard `#` at the end of the topic 
