#!/bin/bash
source /etc/docker_variables.env
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



##### Metube ######
METUBE_DATA=$DOCKER_DATA/metube/downloads
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


### dokuwiki
# 1. Define Base Directory
DOKUWIKI_DIR="$DOCKER_DATA/dokuwiki"

# 2. Define the Array
# DokuWiki only strictly needs a 'config' folder, but we create 'data' 
# explicitly if you want to separate plugins/pages later (optional but good practice)
folders=("config")

# 3. Loop and Create
for folder in "${folders[@]}"; do
    mkdir -p "$DOKUWIKI_DIR/$folder"
    echo "Created: $BASE_DIR/$folder"
done

mkdir -p $DOCKER_COMPOSE_DIR/dokuwiki

cat << EOF > $DOCKER_COMPOSE_DIR/dokuwiki/docker-compose.yml
version: "2.1"
services:
  dokuwiki:
    image: lscr.io/linuxserver/dokuwiki:latest
    container_name: dokuwiki
    environment:
      - PUID=1000  # Your User ID
      - PGID=1000  # Your Group ID
      - TZ=Europe/Bucharest
    volumes:
      # Maps all wiki data (pages, plugins, conf) to your host folder
      # The :z is CRITICAL for Rocky Linux SELinux permission handling
      - $DOKUWIKI_DIR/config:/config:z
    ports:
      - 8080:80 # Access via http://server-ip:8080
    restart: unless-stopped
EOF

cd $DOCKER_COMPOSE_DIR/dokuwiki/
docker compose up -d