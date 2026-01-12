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
    APP_NAME=media-tools
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
MEDIA_DATA=$DOCKER_FAST_DATA/$APP_NAME
MEDIA_DIRECTORIES=("${DOCKER_COMPOSE_DIR}/${APP_NAME}" "${MEDIA_DATA}" "$MEDIA_DATA/config/prowlarr" "$MEDIA_DATA/config/radarr" "$MEDIA_DATA/config/sonarr" "$MEDIA_DATA/config/transmission" "$MEDIA_DATA/incomplete" "$MOVIE_STORAGE/movies" "$SERIES_STORAGE/tv")


log_message "INFO" "Starting container $APP_NAME creation."
log_message "INFO" "Recived Parameters: APP_NAME=$APP_NAME , PUID=$PUID , PGID=$PGID , USER=$MUSER , PASSWD=$PASSWD ."

# Create Stoarage Directory List
create_folders $MEDIA_DIRECTORIES

log_message "INFO" "Creating doker-compose file $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml"
cat << EOF > $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml
services:
  # Indexer Manager
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: ${APP_NAME}-prowlarr
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIME_ZONE
    volumes:
      - $MEDIA_DATA/config/prowlarr:/config
    ports:
      - 9696:9696
    restart: unless-stopped

  # Movie Manager
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: ${APP_NAME}-radarr
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIME_ZONE
    volumes:
      - $MEDIA_DATA/config/radarr:/config
      - $MOVIE_STORAGE/movies:/movies            # Access to the Movie HDD
      - $MOVIE_STORAGE/movies:/downloads/movies  # Matches Transmission path
    ports:
      - 7878:7878
    restart: unless-stopped

  # TV Series Manager
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: ${APP_NAME}-sonarr
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIME_ZONE
    volumes:
      - $MEDIA_DATA/config/sonarr:/config
      - $SERIES_STORAGE/tv:/series            # Access to the Series HDD
      - $SERIES_STORAGE/tv:/downloads/series  # Matches Transmission path
    ports:
      - 8989:8989
    restart: unless-stopped

  # Download Client
  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: ${APP_NAME}-transmission
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIME_ZONE
      - USER=$USER # Change this
      - PASS=$PASSWD # Change this
    volumes:
      - $MEDIA_DATA/config/transmission:/config
      - $MEDIA_DATA/incomplete:/incomplete
      - $MOVIE_STORAGE/movies:/downloads/movies
      - $SERIES_STORAGE/tv:/downloads/tv
    ports:
      - 9091:9091
      - 51413:51413
      - 51413:51413/udp
    restart: unless-stopped
EOF

cat $DOCKER_COMPOSE_DIR/$APP_NAME/docker-compose.yml >> $LOG_FILE

cd $DOCKER_COMPOSE_DIR/$APP_NAME
docker compose up -d
log_message "INFO" "Started docker container $APP_NAME"