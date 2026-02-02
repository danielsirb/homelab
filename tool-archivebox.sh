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
    --port=*)
    PORT="${i#*=}"
    shift # past argument=value
    ;;
    esac
done

if [ -z $APP_NAME ];then
    APP_NAME=archivebox
fi
if [ -z $PUID ];then
    PUID=$MEDIA_PUID
fi
if [ -z $PGID ];then
    PGID=$MEDIA_PGID
fi
if [ -z $PORT ];then
    PORT=5080
fi


# Configure service
ABOX_DATA=$DOCKER_FAST_DATA/$APP_NAME
ABOX_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${ABOX_DATA}")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: ."

# Create Stoarage Directory List
create_folders $ABOX_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  archivebox:
    image: archivebox/archivebox:latest
    container_name: archivebox
    ports:
      - "${PORT}:8000"
    volumes:
      - ${ABOX_DATA}/data:/data
    environment:
      - ALLOW_ALLOWLIST_URLS=True
      - MEDIA_MAX_SIZE=750m
      # Poți seta fusul orar
      - TZ=Europe/Bucharest
      # Activează/Dezactivează ce formate vrei să salveze (economisește spațiu)
      - SAVE_PDF=True
      - SAVE_SCREENSHOT=True
      - SAVE_DOM=True
      - SAVE_SINGLEFILE=True
      - SAVE_WARC=True
    # ArchiveBox are nevoie de permisiuni pentru a scrie în folderul mapat
    user: "${UID:-$PUID}:${GID:-$PGID}"
    restart: unless-stopped
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"