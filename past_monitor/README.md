# Monitor Past Experiments

Here we provide a docker `compose.yaml` that can be used in order to inspect experiments done in the past.

## Steps

- Save the date and time of the experiment (e.g. 25/02/2026  18:43 - 19:00)
- After doing the experiment, Be sure that you have saved the `prometheus` volume  (`/prometheus` directory inside the `prometheus` container). You can also inspect an experiment that was done by others if they have published the `prometheus` volume and you have access to that
- In `compose.yaml`, replace the prometheus bind mount paths with the actual path to your prometheus.yml file and a directory for prometheus data storage
- `docker compose up --build -d`  here

- Launch `grafana_sample` container and login (admin/admin) 
- Go to Connections > Add new data source > Prometheus > URL: `http://prometheus_sample:9090` > Save & Test
- Go to Dashboards > New > Import > `my_custom_dashboard.json` > Select Prometheus as the data source > Import
- Go to the Dashboard and select the time range the experiment was done. 
- You are ready to inspect cpu / memory usage, network traffic of the containers during the experiment


```bash
# prepare the prometheus data
cd lb-n-reals/evolution/prometheus/data
unzip <snapshot_file.zip>


cd ../../../../past_monitor/
docker compose up --build -d
```