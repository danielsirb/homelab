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
    esac
done

if [ -z $APP_NAME ];then
    APP_NAME=time-server
fi


# Configure service
TIME_DATA=$DOCKER_FAST_DATA/$APP_NAME
TIME_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${TIME_DATA}")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: ."

# Create Stoarage Directory List
create_folders $TIME_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  ntp:
    image: cturra/ntp:latest
    container_name: tool-${APP_NAME}
    container_name: ntp-server
    restart: always
    ports:
      - "123:123/udp"
    environment:
      - NTP_SERVERS=time.cloudflare.com,time.google.com
      - LOG_LEVEL=0
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"