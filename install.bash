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
mkdir -p /home/data/docker-containers/immich/library
sed -i 's|^UPLOAD_LOCATION=.*$|UPLOAD_LOCATION=/home/data/docker-containers/immich/library|' .env

# Create Immich container
docker compose up -d

## Check the container
# http://<machine-ip-address>:2283

# Plex Configuration
PLEX_HOME_DIR=/home/data/docker-containers/plex

# --- 1. Define Variables ---

# WARNING: Replace these placeholder values with your actual system IDs and desired paths
PUID=$(id -u)
PGID=$(id -g)
PLEX_CONFIG="$PLEX_HOME_DIR/config"
PLEX_MOVIES="$PLEX_HOME_DIR/library/movies"
PLEX_TV="$PLEX_HOME_DIR/library/tv-shows"
PLEX_CLAIM="YOUR_PLEX_CLAIM_TOKEN"
TIME_ZONE="Europe/Bucharest"
mkdir -p /home/docker-compose/plex

# --- 2. Create the Directory Structure (Best Practice) ---
mkdir -p "$PLEX_CONFIG"
mkdir -p "$PLEX_MOVIES"
mkdir -p "$PLEX_TV"

# --- 3. Generate the docker-compose.yml File using a Here Document (EOF) ---

# The variables within the EOF block will be expanded by the shell.
cat << EOF > /home/docker-compose/plex/docker-compose.yml
version: "2.1"
services:
  plex:
    image: plexinc/pms-docker:latest
    container_name: plex
    network_mode: host
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIME_ZONE
      - PLEX_CLAIM=$PLEX_CLAIM
    volumes:
      # Plex Configuration
      - $PLEX_CONFIG:/config
      # Media Libraries (Read-Only)
      - $PLEX_MOVIES:/data/movies:ro
      - $PLEX_TV:/data/tv:ro
    restart: unless-stopped
EOF

echo "✅ docker-compose.yml created successfully with the following paths:"
echo "   Config: $PLEX_CONFIG"
echo "   Movies: $PLEX_MOVIES"
echo "   TV:     $PLEX_TV"
echo ""
echo "Run 'docker compose up -d' to start Plex."

# Change to docker compose directory and start the container
cd /home/docker-compose/plex/
docker compose up -d


# For nabucasa i need
#/etc/udev/rules.d/99-skyconnect.rules
#with content
# Rule for SkyConnect USB device
#SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ttyUSBSkyConnect"
cat << EOF > /etc/udev/rules.d/99-skyconnect.rules
# Rule for SkyConnect USB device
#SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ttyUSBSkyConnect"
EOF

# Configure HA with standard configuration

HA_CONF_DIR=/home/data/docker-containers/homeassistant/config
mkdir -p $HA_CONF_DIR
mkdir -p /home/docker-compose/homeassistant
cat << EOF > /home/docker-compose/homeassistant/docker-compose.yml
services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      - $HA_CONF_DIR:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    devices:
      - /dev/ttyUSBSkyConnect
    restart: unless-stopped
    privileged: true
    network_mode: host
EOF

cd /home/docker-compose/homeassistant
docker compose up -d


# Configure Paperless-ngx



## Configure Mealie
# We need to change the secret of the DB
MEALIE_DATA=/home/data/docker-containers/mealie

mkdir -p /home/docker-compose/mealie
mkdir -p $MEALIE_DATA
cat << EOF > /home/docker-compose/mealie/docker-compose.yml
version: '3.8'

services:
  mealie:
    image: ghcr.io/mealie-recipes/mealie:latest
    container_name: mealie
    restart: always
    ports:
      # Maps host port 9925 to container port 9000
      - "9925:9000"
    volumes:
      # Persistent storage for user data (images, backups, configuration)
      - $MEALIE_DATA/mealie-data:/app/data/
    environment:
      # --- General Settings ---
      - ALLOW_SIGNUP=true
      - PUID=1000                   # Change to your user's PUID/UID
      - PGID=1000                   # Change to your user's PGID/GID
      - TZ=Europe/London            # Set your correct TimeZone
      # --- Database Settings (Connects to the 'postgres' service) ---
      - POSTGRES_USER=mealie_user
      - POSTGRES_PASSWORD=R!^hZ#2^zRiJChm27ru2^98  # << CHANGE THIS
      - POSTGRES_SERVER=postgres              # Matches the service name below
      - POSTGRES_PORT=5432
      - POSTGRES_DB=mealie_db

  postgres:
    image: postgres:15-alpine
    container_name: postgres
    restart: always
    # NOTE: The host port (e.g., 5432) is commented out for security.
    # It is accessible internally by the 'mealie' service via the network.
    # If you need external access (e.g., for pgAdmin), uncomment the ports line.
    # ports:
    #   - "5432:5432"
    volumes:
      # Persistent storage for the PostgreSQL database files
      - $MEALIE_DATA/postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=mealie_user
      - POSTGRES_PASSWORD=R!^hZ#2^zRiJChm27ru2^98 # << MUST match Mealie's POSTGRES_PASSWORD 
      - POSTGRES_DB=mealie_db
EOF

cd /home/docker-compose/mealie
docker compose up -d