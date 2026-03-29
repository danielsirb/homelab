#!/bin/bash
source /etc/docker_variables.env
LOG_FILE="/var/log/docker-updates.log"
source $SCRIPT_LIB

# Configuration
PARENT_DIR="/home/docker-compose"

log_message "INFO" "######################## Global Update Check Started: ########################"

# Find all directories containing a docker-compose.yml (or .yaml) file
find "$PARENT_DIR" -maxdepth 2 -name "docker-compose.y*ml" | while read -r compose_file; do

    # Get the directory containing the current compose file
    subdir=$(dirname "$compose_file")
    project_name=$(basename "$subdir")

    log_message "SERVICE" "-------- Checking project: $project_name... --------"

    # Enter the directory
    pushd "$subdir" > /dev/null || continue

    # Identify services in this specific compose file
    services=$(docker compose ps --services)

    for service in $services; do
        # Get current image details
        # We grab the Image Name (with tag) and the unique Image ID (SHA)
        image_name=$(docker compose config --format json | jq -r ".services.\"$service\".image")

        # Get the local ID of that image
        old_sha=$(docker images -q "$image_name" | head -n 1)

        log_message "INFO" "Detected image: $image_name with sha: $old_sha"
        # Pull updates
        # Pulling retrieves the latest layers for the defined tag (e.g., :latest or :1.2)
        if docker compose pull -q "$service" > /dev/null 2>&1; then
            
            # Get new image details
            new_sha=$(docker images -q "$image_name" | head -n 1)
            log_message "INFO" "New SHA is: $new_sha"
            # Compare SHAs to see if a newer build exists for that tag
            if [ "$old_sha" != "$new_sha" ]; then
                
                # Apply the update
                if docker compose up -d "$service" > /dev/null 2>&1; then
                    # Log the success
                    log_message "INFO" "Update of container PROJECT: $project_name | SERVICE: $service | ACTION: Updated | FROM: ${old_sha:0:12} | TO: ${new_sha:0:12} "
                else
                    log_message "ERROR" "Failed to restart $service in $project_name"
                fi
            else
                log_message "INFO" "UPDATE not needed for PROJECT: $project_name | SERVICE: $service"
            fi
        fi
    done
    log_message "INFO" "-------- Checking finished for project: $project_name... --------"
    # Return to previous directory
    popd > /dev/null
done

log_message "INFO" "######################## Global Update Check Finished: ########################"