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
    APP_NAME=nginx-proxy
fi

# Configure Nginx-proxy
NGINXPROXY_DATA=$DOCKER_FAST_DATA/$APP_NAME
NGINXPROXY_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${NGINXPROXY_DATA}" "${NGINXPROXY_DATA}/data" "${NGINXPROXY_DATA}/letsencrypt")

log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: APP_NAME=$APP_NAME."

# Create Stoarage Directory List
create_folders $NGINXPROXY_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - '80:80'   # Public HTTP Port
      - '443:443' # Public HTTPS Port
      - '81:81'   # Admin Web Interface Port
    volumes:
      - $NGINXPROXY_DATA/data:/data
      - $NGINXPROXY_DATA/letsencrypt:/etc/letsencrypt

networks:
  default:
    name: proxy_network
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d