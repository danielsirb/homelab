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
    esac
done

if [ -z $APP_NAME ];then
    APP_NAME=heimdall
fi
if [ -z $PUID ];then
    PUID=$MEDIA_PUID
fi
if [ -z $PGID ];then
    PGID=$MEDIA_PGID
fi


# Configure service
DASHBOARD_DATA=$DOCKER_FAST_DATA/$APP_NAME
DASHBOARD_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${DASHBOARD_DATA}" "${DASHBOARD_DATA}/config")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: ."

# Create Stoarage Directory List
create_folders $DASHBOARD_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  heimdall:
    image: lscr.io/linuxserver/heimdall:latest
    container_name: tool-${APP_NAME}
    environment:
      - PUID=${PUID} # Run 'id' in your terminal to find your UID
      - PGID=${PGID} # Run 'id' in your terminal to find your GID
      - TZ=${TIME_ZONE} # Set your specific timezone
    volumes:
      - ${DASHBOARD_DATA}/config:/config
    ports:
      - 9080:80
      - 9443:443
    restart: unless-stopped
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"