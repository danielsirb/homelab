#/bin/bash
source /etc/docker_variables.env
source $SCRIPT_LIB
HOSTNAME_IP=$(hostname -i)
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
    APP_NAME=n8n
fi

# Configure service
N8N_DATA=$DOCKER_FAST_DATA/$APP_NAME
N8N_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${N8N_DATA}" "${N8N_DATA}/n8n_data")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: ."

# Create Stoarage Directory List
create_folders $N8N_DIRECTORIES
chown -r 1000:1000 ${N8N_DATA}/n8n_data

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: tool-${APP_NAME}
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=http://${HOSTNAME_IP}:5678/
      - N8N_SECURE_COOKIE=false # This should be removed if you use a dns
      - GENERIC_TIMEZONE=$TIME_ZONE
    volumes:
      - $N8N_DATA/n8n_data:/home/node/.n8n

volumes:
  n8n_data:
    external: false
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"