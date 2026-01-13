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
    -p=* | --password=*)
    PASSWORD_VAR="${i#*=}"
    shift # past argument=value
    ;;
    -d=* | --directory=*)
    LIB_DIR="${i#*=}"
    shift # past argument=value
    ;;
    esac
done

if [ -z $APP_NAME ];then
    APP_NAME=immich-app
fi
if [ -z $PUID ];then
    PUID=$MEDIA_PUID
fi
if [ -z $PGID ];then
    PGID=$MEDIA_PGID
fi
if [ -z $PASSWORD_VAR ];then
    PASSWORD_VAR=$(generate_random_string 20 1)
fi
if [ -z $LIB_DIR ];then
    LIB_DIR=${DOCKER_SLOW_DATA}
fi

# Configure service
IMMICH_DATA=$LIB_DIR/$APP_NAME
IMMICH_FAST_DATA=$DOCKER_FAST_DATA/$APP_NAME
IMMICH_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${IMMICH_DATA}" "${IMMICH_FAST_DATA}" "$IMMICH_DATA/library")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: APP_NAME=$APP_NAME , PUID=$PUID , PGID=$PGID , PASSWORD_VAR=$PASSWORD_VAR , LIB_DIR=$LIB_DIR ."

# Create Stoarage Directory List
create_folders $IMMICH_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"

cd "$DOCKER_COMPOSE_DIR/$APP_NAME"
wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

# Get important env file that has to be copied an migrated in case it is needed.
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env

# Set a secure password for Posgress DB needed for Immich 
# This field will be later changed with a secret as phrase
# sed -i 's/^DB_PASSWORD=.*$/DB_PASSWORD=jjZ77fY8c3h!M8wvYRT4H@Q/' .env
sed -i "s|^DB_PASSWORD=.*$|DB_PASSWORD=$PASSWORD_VAR|" .env

# Set the timezone
sed -i -e '/^#[[:space:]]*TZ=/ c\TZ=Europe/Bucharest' -e '/^TZ=/ c\TZ=Europe/Bucharest' .env

sed -i "s|^UPLOAD_LOCATION=.*$|UPLOAD_LOCATION=$IMMICH_DATA/library|" .env

# Set immich db location
create_folders $DOCKER_DATA/$APP_NAME/postgres_db
sed -i "s|^DB_DATA_LOCATION=.*$|DB_DATA_LOCATION=$IMMICH_FAST_DATA/postgres_db|" .env

log_message "INFO" "Created docker compose file:"
cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

log_message "INFO" "Created docker .env file:"
cat $DOCKER_COMPOSE_DIR/$APP_NAME/.env >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME

# Create Immich container
docker compose up -d

## Check the container
# http://<machine-ip-address>:2283
