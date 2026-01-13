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
    --db-passwd=*)
    DBPASSWD="${i#*=}"
    shift # past argument=value
    ;;
    esac
done

if [ -z $APP_NAME ];then
    APP_NAME=paperless-ng
fi
if [ -z $PUID ];then
    PUID=$MEDIA_PUID
fi
if [ -z $PGID ];then
    PGID=$MEDIA_PGID
fi
if [ -z $DBPASSWD ];then
    DBPASSWD=$(generate_random_string 20 1)
fi

# Configure service
PAPERLESS_DATA=$DOCKER_FAST_DATA/$APP_NAME
PAPERLESS_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${PAPERLESS_DATA}" "$PAPERLESS_DATA/broker/redis" "$PAPERLESS_DATA/db" "$PAPERLESS_DATA/webserver/data" "$PAPERLESS_DATA/webserver/media" "$PAPERLESS_DATA/webserver/export" "$PAPERLESS_DATA/webserver/consume")
PAPERLESS_SECRET_KEY=$(generate_random_string 30 1)

log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: ."

# Create Stoarage Directory List
create_folders $PAPERLESS_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  broker:
    container_name: ${APP_NAME}-broker
    image: docker.io/library/redis:7
    restart: unless-stopped
    volumes:
      - $PAPERLESS_DATA/broker/redis:/data:z  # :z fixes SELinux permissions on Rocky

  db:
    container_name: ${APP_NAME}-db
    image: docker.io/library/postgres:16
    restart: unless-stopped
    volumes:
      - $PAPERLESS_DATA/db:/var/lib/postgresql/data:z
    environment:
      POSTGRES_DB: paperless
      POSTGRES_USER: paperless
      POSTGRES_PASSWORD: $DBPASSWD # Change this for security!

  webserver:
    container_name: ${APP_NAME}-webserver
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    restart: unless-stopped
    depends_on:
      - db
      - broker
    ports:
      - "8000:8000"
    volumes:
      - $PAPERLESS_DATA/webserver/data:/usr/src/paperless/data:z
      - $PAPERLESS_DATA/webserver/media:/usr/src/paperless/media:z
      - $PAPERLESS_DATA/webserver/export:/usr/src/paperless/export:z
      - $PAPERLESS_DATA/webserver/consume:/usr/src/paperless/consume:z
    environment:
      PAPERLESS_REDIS: redis://broker:6379
      PAPERLESS_DBHOST: db
      PAPERLESS_DBPASS: $DBPASSWD # Must match DB password above
      PAPERLESS_SECRET_KEY: $PAPERLESS_SECRET_KEY
      PAPERLESS_URL: http://localhost:8000
      PAPERLESS_TIME_ZONE: $TIME_ZONE
      PAPERLESS_OCR_LANGUAGES: ron
      PAPERLESS_OCR_LANGUAGE: ron+eng
      PAPERLESS_FILENAME_FORMAT: "{created_year}/{correspondent}/{title}"
      USERMAP_UID: $PUID # Your user ID (run `id` to check)
      USERMAP_GID: $PGID # Your group ID
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"