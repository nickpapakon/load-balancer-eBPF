FROM mqtt_base

LABEL os.version="Ubuntu 22.04.5 LTS"
LABEL maintainer="docker-broker-shared-subs"


WORKDIR /home/broker

# Copy the source code into the container.
COPY . .

RUN chmod +x setup.sh

# setup network interfaces and start the application
ENTRYPOINT [ "/home/broker/setup.sh" ]