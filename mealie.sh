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
    APP_NAME=mealie
fi
if [ -z $PUID ];then
    PUID=$MEDIA_PUID
fi
if [ -z $PGID ];then
    PGID=$MEDIA_PGID
fi
if [ -z $DBUSER ];then
    DBUSER=mealie_user
fi
if [ -z $DBNAME ];then
    DBNAME=mealie_db
fi
if [ -z $DBPASSWD ];then
    DBPASSWD=$(generate_random_string 20 1)
fi

## Configure Mealie
# We need to change the secret of the DB
MEALIE_DATA=$DOCKER_FAST_DATA/$APP_NAME
MEALIE_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${MEALIE_DATA}")

log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: PUID=$PUID ; PGID=$PGID ; DBUSER=$DBUSER ; DBPASSWD=$DBPASSWD ."

# Create Stoarage Directory List
create_folders $MEALIE_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  mealie:
    image: ghcr.io/mealie-recipes/mealie:latest
    container_name: tool-${APP_NAME}
    restart: always
    ports:
      # Maps host port 9925 to container port 9000
      - "9925:9000"
    volumes:
      # Persistent storage for user data (images, backups, configuration)
      - $MEALIE_DATA/mealie-data:/app/data/
    environment:
      # --- General Settings ---
      - ALLOW_SIGNUP=true
      - PUID=$PUID                   # Change to your user's PUID/UID
      - PGID=$PGID                   # Change to your user's PGID/GID
      - TZ=$TIME_ZONE            # Set your correct TimeZone
      # --- Database Settings (Connects to the 'postgres' service) ---
      - POSTGRES_USER=$DBUSER
      - POSTGRES_PASSWORD=$DBPASSWD  # << CHANGE THIS
      - POSTGRES_SERVER=postgres              # Matches the service name below
      - POSTGRES_PORT=5432
      - POSTGRES_DB=$DBNAME

  postgres:
    image: postgres:15-alpine
    container_name: postgres-${APP_NAME}
    restart: always
    # NOTE: The host port (e.g., 5432) is commented out for security.
    # It is accessible internally by the 'mealie' service via the network.
    # If you need external access (e.g., for pgAdmin), uncomment the ports line.
    # ports:
    #   - "5432:5432"
    volumes:
      # Persistent storage for the PostgreSQL database files
      - $MEALIE_DATA/postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=$DBUSER
      - POSTGRES_PASSWORD=$DBPASSWD # << MUST match Mealie's POSTGRES_PASSWORD 
      - POSTGRES_DB=$DBNAME
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"