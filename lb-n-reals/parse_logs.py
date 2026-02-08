import re
import argparse

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--reals", type=int, default=6)
    parser.add_argument("--log_dir", type=str, default=".")
    args = parser.parse_args()
    sent_publish_msgs = {}
    # (client, real_num) -> number of messages
    
    for real_num in range(1, 1 + args.reals):
        with open(f"{args.log_dir}/real_{real_num}.log", "r") as logfile:
            lines = logfile.readlines()

        for line in lines:
            regex_pattern = r"PUBLISH from client_([0-9]+).*(measurements[^']+).*([0-9]+)\s+bytes"
            publish_msg = re.search(regex_pattern, line)
            if not publish_msg:
                continue
            
            client = int(publish_msg.group(1))
            topic = publish_msg.group(2)
            message_len = int(publish_msg.group(3))
            key = (client, real_num)

            if key not in sent_publish_msgs:
                sent_publish_msgs[key] = 0
            sent_publish_msgs[key] += 1
        
    for key, value in sent_publish_msgs.items():
        print(f"Client {key[0]} sent {value} PUBLISH messages to real {key[1]}")



    
    
