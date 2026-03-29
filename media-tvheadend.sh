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
    --user=*)
    MUSER="${i#*=}"
    shift # past argument=value
    ;;
    --passwd=*)
    PASSWD="${i#*=}"
    shift # past argument=value
    ;;
    esac
done

if [ -z $APP_NAME ];then
    APP_NAME=tvheadend
fi
if [ -z $PUID ];then
    PUID=$MEDIA_PUID
fi
if [ -z $PGID ];then
    PGID=$MEDIA_PGID
fi
if [ -z $USER ];then
    USER=admin
fi
if [ -z $PASSWD ];then
    PASSWD=$(generate_random_string 20 1)
fi

# Configure service
TV_DATA=$DOCKER_FAST_DATA/$APP_NAME
TV_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${TV_DATA}/config" "$SERIES_STORAGE/tv-recordings")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: ."

# Create Stoarage Directory List
create_folders $TV_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  tvheadend:
    image: lscr.io/linuxserver/tvheadend:latest
    container_name: tool-${APP_NAME}
    environment:
      - PUID=$PUID # Use 'id $user' in terminal to find your PUID
      - PGID=$PGID # Use 'id $user' in terminal to find your PGID
      - TZ=Europe/Bucharest
      - RUN_OPTS= # Optional: Add extra startup arguments here
    volumes:
      - $TV_DATA/config:/config
      - $SERIES_STORAGE/tv-recordings:/recordings
    ports:
      - 9981:9981 # Web Interface
      - 9982:9982 # HTSP (for Kodi/clients)
    devices:
      - /dev/dvb:/dev/dvb # Passes your physical tuner to the container
      - /dev/dri:/dev/dri # Optional: Passes GPU for hardware transcoding
    restart: unless-stopped

  antennas:
    image: thejf/antennas:latest
    container_name: antennas
    network_mode: host
    environment:
      - ANTENNAS_URL=http://localhost:5004
      # If user & password is needed we can use:
      #- TVHEADEND_URL=http://${USER}:${PASSWD}@localhost:9981 
      - TVHEADEND_URL=http://localhost:9981
      - TUNER_COUNT=2
    restart: unless-stopped
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"