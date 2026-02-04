import re
import argsparse

if __name__ == '__main__':
    args = argsparse()
    args.parse_args("--reals", type=int, default=6)
    lines = []
    sent_to_broker = {}
    # client -> (real_num, number of messages)
    # organize this DS in class
    for real_num in range(1, 1 + args.num):
        with open(f"real_{real_num}", "r") as logfile:
            lines = logfile.readlines()

        for line in lines:
            regex_pattern = r"PUBLISH from (client_[0-9]+).*(measurements[^']+).*([0-9]+)\s+bytes"
            publish_msg = re.match(line, regex_pattern)
            client = publish_msg.group(1)
            topic = publish_msg.group(2)
            message_len = publish_msg.group(3)

            if client in sent_to_broker.keys():
                assert sent_to_broker[client] == real_num
            sent_to_broker[client] = 

    
    
