#/bin/bash
source /etc/docker_variables.env
source $SCRIPT_LIB

# --- Parameter Parsing ---
# Use getopt to parse long and short options
for i in "$@"; do
  case $i in
    -n=*|--app-name=*)
    APP_NAME="${i#*=}"
    shift # past argument=value
    ;;
    --user-id=*)
    PUID="${i#*=}"
    shift # past argument=value
    ;;
    --group-id=*)
    PGID="${i#*=}"
    shift # past argument=value
    ;;
    --db-user=*)
    DBUSER="${i#*=}"
    shift # past argument=value
    ;;
    --db-name=*)
    DBNAME="${i#*=}"
    shift # past argument=value
    ;;
    --db-passwd=*)
    DBPASSWD="${i#*=}"
    shift # past argument=value
    ;;
    esac
done

if [ -z $APP_NAME ];then
    APP_NAME=homeassistant
fi
if [ -z $PUID ];then
    PUID=$MEDIA_PUID
fi
if [ -z $PGID ];then
    PGID=$MEDIA_PGID
fi
if [ -z $DBUSER ];then
    DBUSER=
fi
if [ -z $DBNAME ];then
    DBNAME=
fi
if [ -z $DBPASSWD ];then
    DBPASSWD=$(generate_random_string 20 1)
fi

# Configure service
HA_DATA=$DOCKER_FAST_DATA/$APP_NAME
HA_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${HA_DATA}" "$HA_DATA/config" "$HA_DATA/media")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: ."

# Create Stoarage Directory List
create_folders $HA_DIRECTORIES

log_message "INFO" "Checking for Nabucasa adapter rule"

if [ ! -f "/etc/udev/rules.d/99-skyconnect.rules" ];then
log_message "INFO" "File /etc/udev/rules.d/99-skyconnect.rules was created"
cat << EOF > /etc/udev/rules.d/99-skyconnect.rules
# Rule for SkyConnect USB device
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ttyUSBSkyConnect"
EOF
fi

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  homeassistant:
    container_name: tool-${APP_NAME}
    image: "ghcr.io/home-assistant/home-assistant:stable"
    dns: 
      - 1.1.1.1 # Cloudflare DNS (Very fast and reliable)
      - 8.8.8.8 # Google Public DNS (Secondary backup)
    volumes:
      - $HA_DATA/config:/config
      - $HA_DATA/media:/media:ro
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    devices:
      - /dev/ttyUSBSkyConnect
    restart: unless-stopped
    privileged: true
    network_mode: host
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"