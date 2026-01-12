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
    -t=* | --plex_token=*)
    PLEX_CLAIM="${i#*=}"
    shift # past argument=value
    ;;
    esac
done

if [ -z $APP_NAME ];then
    APP_NAME=plex
fi
if [ -z $PUID ];then
    PUID=$MEDIA_PUID
fi
if [ -z $PGID ];then
    PGID=$MEDIA_PGID
fi

PLEX_DATA=$DOCKER_FAST_DATA/$APP_NAME
PLEX_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${PLEX_DATA}/config" "${MOVIE_STORAGE}/movies" "${SERIES_STORAGE}/tv")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: ."

# Create Stoarage Directory List
create_folders $PLEX_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"

# Create Stoarage Directory List
create_folders $PLEX_DIRECTORY_LIST
# Create App docker compose directory
create_folders "$DOCKER_COMPOSE_DIR/$APP_NAME"

cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  plex:
    image: plexinc/pms-docker:latest
    container_name: plex
    network_mode: host
    devices:
      - /dev/dri:/dev/dri # Passes the entire GPU interface
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIME_ZONE
      - PLEX_CLAIM=$PLEX_CLAIM
      - DEVICE=/dev/dri/renderD128
    volumes:
      # Plex Configuration
      - ${PLEX_DATA}/config:/config
      # Media Libraries (Read-Only)
      - ${MOVIE_STORAGE}/movies:/data/movies:ro
      - ${SERIES_STORAGE}/tv:/data/tv:ro
    restart: unless-stopped
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"