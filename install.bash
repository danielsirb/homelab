#!/bin/bash
# General Variables
DOCKER_DATA=/home/data/docker-containers
DOCKER_COMPOSE_DIR=/home/docker-compose
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

mkdir -p $DOCKER_COMPOSE_DIR/immich-app
cd $DOCKER_COMPOSE_DIR/immich-app


wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

# Get important env file that has to be copied an migrated in case it is needed.
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env

# Set a secure password for Posgress DB needed for Immich 
# This field will be later changed with a secret as phrase
sed -i 's/^DB_PASSWORD=.*$/DB_PASSWORD=jjZ77fY8c3h!M8wvYRT4H@Q/' .env

# Set the timezone
sed -i -e '/^#[[:space:]]*TZ=/ c\TZ=Europe/Bucharest' -e '/^TZ=/ c\TZ=Europe/Bucharest' .env

# Set immich libraries location
mkdir -p $DOCKER_DATA/immich/library
sed -i 's|^UPLOAD_LOCATION=.*$|UPLOAD_LOCATION=$DOCKER_DATA/immich/library|' .env

# Create Immich container
docker compose up -d

## Check the container
# http://<machine-ip-address>:2283

# Plex Configuration
PLEX_HOME_DIR=$DOCKER_DATA/plex

# --- 1. Define Variables ---

# WARNING: Replace these placeholder values with your actual system IDs and desired paths
PUID=$(id -u)
PGID=$(id -g)
PLEX_CONFIG="$PLEX_HOME_DIR/config"
PLEX_MOVIES="$PLEX_HOME_DIR/library/movies"
PLEX_TV="$PLEX_HOME_DIR/library/tv-shows"
PLEX_CLAIM="YOUR_PLEX_CLAIM_TOKEN"
TIME_ZONE="Europe/Bucharest"
mkdir -p $DOCKER_COMPOSE_DIR/plex

# --- 2. Create the Directory Structure (Best Practice) ---
mkdir -p "$PLEX_CONFIG"
mkdir -p "$PLEX_MOVIES"
mkdir -p "$PLEX_TV"

# --- 3. Generate the docker-compose.yml File using a Here Document (EOF) ---

# The variables within the EOF block will be expanded by the shell.
cat << EOF > $DOCKER_COMPOSE_DIR/plex/docker-compose.yml
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
cd $DOCKER_COMPOSE_DIR/plex/
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

HA_CONF_DIR=$DOCKER_DATA/homeassistant/config
HA_MEDIA_DIR=$DOCKER_DATA/homeassistant/media
mkdir -p $HA_CONF_DIR
mkdir -p $DOCKER_COMPOSE_DIR/homeassistant
cat << EOF > $DOCKER_COMPOSE_DIR/homeassistant/docker-compose.yml
services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    dns: 
      - 1.1.1.1 # Cloudflare DNS (Very fast and reliable)
      - 8.8.8.8 # Google Public DNS (Secondary backup)
    volumes:
      - $HA_CONF_DIR:/config
      - $HA_MEDIA_DIR:/media:ro
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    devices:
      - /dev/ttyUSBSkyConnect
    restart: unless-stopped
    privileged: true
    network_mode: host
EOF

cd $DOCKER_COMPOSE_DIR/homeassistant
docker compose up -d


# Configure Paperless-ngx
PAPERLESS_DIR=$DOCKER_DATA/paperless
PAPERLESS_FOLDERS=("config" "data" "media" "export" "consume")
for folder in "${PAPERLESS_FOLDERS[@]}"; do
    mkdir -p "$PAPERLESS_DIR/$folder"
    echo "Created: $PAPERLESS_DIR/$folder"
done

mkdir -p $DOCKER_COMPOSE_DIR/paperless
cat << EOF > $DOCKER_COMPOSE_DIR/paperless/docker-compose.yml
version: "3.4"
services:
  broker:
    image: docker.io/library/redis:7
    restart: unless-stopped
    volumes:
      - ./redis:/data:z  # :z fixes SELinux permissions on Rocky

  db:
    image: docker.io/library/postgres:16
    restart: unless-stopped
    volumes:
      - ./db:/var/lib/postgresql/data:z
    environment:
      POSTGRES_DB: paperless
      POSTGRES_USER: paperless
      POSTGRES_PASSWORD: paperless_db_password # Change this for security!

  webserver:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    restart: unless-stopped
    depends_on:
      - db
      - broker
    ports:
      - "8000:8000"
    volumes:
      - $PAPERLESS_DIR/data:/usr/src/paperless/data:z
      - $PAPERLESS_DIR/media:/usr/src/paperless/media:z
      - $PAPERLESS_DIR/export:/usr/src/paperless/export:z
      - $PAPERLESS_DIR/consume:/usr/src/paperless/consume:z
    environment:
      PAPERLESS_REDIS: redis://broker:6379
      PAPERLESS_DBHOST: db
      PAPERLESS_DBPASS: paperless_db_password # Must match DB password above
      PAPERLESS_SECRET_KEY: change-me-to-a-long-random-string
      PAPERLESS_URL: http://localhost:8000
      PAPERLESS_TIME_ZONE: Europe/Bucharest
      PAPERLESS_OCR_LANGUAGE: eng # Change to 'ron' for Romanian OCR support
      USERMAP_UID: 1000 # Your user ID (run `id` to check)
      USERMAP_GID: 1000 # Your group ID
EOF

cd $DOCKER_COMPOSE_DIR/paperless/
docker compose up -d

## Configure Mealie
# We need to change the secret of the DB
MEALIE_DATA=$DOCKER_DATA/mealie

mkdir -p $DOCKER_COMPOSE_DIR/mealie
mkdir -p $MEALIE_DATA
cat << EOF > $DOCKER_COMPOSE_DIR/mealie/docker-compose.yml
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

cd $DOCKER_COMPOSE_DIR/mealie
docker compose up -d

METUBE_DATA=/home/data/metube/downloads
mkdir -p $DOCKER_COMPOSE_DIR/metube/downloads
cat << EOF > $DOCKER_COMPOSE_DIR/metube/docker-compose.yml
services:
  metube:
    image: ghcr.io/alexta69/metube
    container_name: metube
    restart: unless-stopped
    ports:
      - "8081:8081" # Web UI access
    volumes:
      - $METUBE_DATA:/downloads # IMPORTANT: Persistent storage for files
EOF
cd $DOCKER_COMPOSE_DIR/metube/
docker compose up -d