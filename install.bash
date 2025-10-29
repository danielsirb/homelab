#!/bin/bash

#Update OS
dnf update -y

# Install Git & Tools
dnf install git -y
dnf install wget -y

dnf -y install dnf-utils
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

#Install Docker and its components:
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

#Start and enable the Docker service
systemctl start docker
systemctl enable docker

#Check Docker version
docker --version
docker compose version

mkdir -p /home/docker-compose/immich-app
cd /home/docker-compose/immich-app


wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

# Get important env file that has to be copied an migrated in case it is needed.
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env

# Set a secure password for Posgress DB needed for Immich 
# This field will be later changed with a secret as phrase
sed -i 's/^DB_PASSWORD=.*$/DB_PASSWORD=jjZ77fY8c3h!M8wvYRT4H@Q/' .env

# Set the timezone
sed -i -e '/^#[[:space:]]*TZ=/ c\TZ=Europe/Bucharest' -e '/^TZ=/ c\TZ=Europe/Bucharest' .env

# Set immich libraries location
mkdir -p /data/docker-containers/immich/library
sed -i 's|^UPLOAD_LOCATION=.*$|UPLOAD_LOCATION=/data/docker-containers/immich/library|' .env

# Create Immich container
docker compose up -d

## Check the container
# http://<machine-ip-address>:2283

s
