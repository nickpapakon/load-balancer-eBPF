import json
import subprocess
import os
import time
import argparse

# Configuration

CONTAINER_NAME = "katran"
OUTPUT_FILE = "/var/lib/node_exporter/textfile_metrics/xdp_stats.prom"
TEMP_FILE = OUTPUT_FILE + ".tmp"

def collect_xdp_stats(bpf_prog_name="xdp_root"):
    try:
        # 1. Run the docker command
        cmd = ["docker", "exec", CONTAINER_NAME, "bpftool", "prog", "show", "name", bpf_prog_name, "--json"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        
        # 2. Parse JSON into a dictionary
        # bpftool usually returns a list [ {...} ]
        data_raw = json.loads(result.stdout)
        
        if isinstance(data_raw, list) and len(data_raw) > 0:
            prog = data_raw[0]
        elif isinstance(data_raw, dict):
            prog = data_raw
        else:
            print("No data found for xdp_root")
            return

        # 3. Extract the metrics
        # We use .get() to avoid KeyErrors if stats are disabled
        metrics = {
            "id": prog.get("id"),
            "name": prog.get("name"),
            "run_time_ns": prog.get("run_time_ns", 0),
            "run_cnt": prog.get("run_cnt", 0)
        }

        # 4. Write to Prometheus textfile format
        with open(TEMP_FILE, "w") as f:
            f.write("# HELP xdp_program_run_time_ns_total Total run time in nanoseconds\n")
            f.write("# TYPE xdp_program_run_time_ns_total counter\n")
            f.write(f'xdp_program_run_time_ns_total{{id="{metrics["id"]}",name="{metrics["name"]}"}} {metrics["run_time_ns"]}\n')
            
            f.write("# HELP xdp_program_run_cnt_total Total number of times the program ran\n")
            f.write("# TYPE xdp_program_run_cnt_total counter\n")
            f.write(f'xdp_program_run_cnt_total{{id="{metrics["id"]}",name="{metrics["name"]}"}} {metrics["run_cnt"]}\n')

        # Atomic move
        os.replace(TEMP_FILE, OUTPUT_FILE)
        print(f"Successfully updated {OUTPUT_FILE}")

    except subprocess.CalledProcessError as e:
        print(f"Error executing docker: {e.stderr}")
    except json.JSONDecodeError:
        print("Error decoding JSON from bpftool")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":

    # take
    #  SAMPLE_INTERVAL = 3  # gather metrics every __ seconds
    # from command line argument

    parser = argparse.ArgumentParser(description="Scrape XDP program metrics from a Docker container and expose them in Prometheus textfile format.")
    parser.add_argument("--bpf_prog_name", type=str, default="xdp_root", help="Name of the BPF program to scrape (default: xdp_root)")
    parser.add_argument("--interval", type=int, default=3, help="Interval in seconds between metric collections (default: 3)")
    args = parser.parse_args()
    SAMPLE_INTERVAL = args.interval

    start_time = time.time()

    while True:
        
        time_now = time.time()
        if time_now - start_time > SAMPLE_INTERVAL:  
            start_time = time_now  # Reset the timer
            collect_xdp_stats(args.bpf_prog_name)
        else:
            time.sleep(1)  # Sleep briefly to avoid tight loop