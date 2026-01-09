log_message() {
    local LOG_LEVEL="$1"
    local MESSAGE="$2"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    # Format: [YYYY-MM-DD HH:MM:SS] [LEVEL] Message
    printf "[%s] [%s] %s\n" "$TIMESTAMP" "$LOG_LEVEL" "$MESSAGE" >> "$LOG_FILE"
    
    # Optional: Also print to terminal (standard error)
    if [[ "$LOG_LEVEL" == "ERROR" ]]; then
        printf "[%s] [%s] %s\n" "$TIMESTAMP" "$LOG_LEVEL" "$MESSAGE" >&2
    fi
}

# Usage examples:
#log_message "INFO" "Starting the backup process."
#log_message "WARN" "Disk space is reaching 80% capacity."
#log_message "ERROR" "Failed to connect to the database."

create_folders() {
  # Localize variables to keep them from polluting the global environment
  local FOLDER_NAME
  local EXIT_CODE=0
  
  # Check if any arguments were passed to the function
  if [ "$#" -eq 0 ]; then
    log_message "ERROR" "No folder names provided to the create_folders function." >&2
    og_message "INFO" "Usage: create_folders <folder1> <folder2> [\"folder with space\"] ..."
    return 1 
  fi

  for FOLDER_NAME in "$@"; do
    if [ -d "$FOLDER_NAME" ]; then
      log_message "WARN" "Skipping: Folder '$FOLDER_NAME' already exists."
      continue 
    fi
    if mkdir -p "$FOLDER_NAME"; then
      log_message "INFO" "Created folder '$FOLDER_NAME'."
    else
      log_message "ERROR" "Could not create folder '$FOLDER_NAME'." >&2
      EXIT_CODE=1 
    fi
  done
  
  return $EXIT_CODE
}

generate_random_string() {
  # Localize variables
  local LENGTH=${1:-16}   # Default length is 16
  local INCLUDE_SPECIAL=${2:-0} # Default to excluding special characters (0)

  local CHAR_SET_STANDARD='A-Za-z0-9'
  # FIX: Move '-' to the start/end and use double backslashes for tr
  # The hyphen (-) is safe at the beginning/end of a set.
  # The backslash must be double-escaped for tr to receive one literal backslash.
  local CHAR_SET_SPECIAL='-!@#$%^&*()_+{}:"<>?~`|\[\]\\='
  local FINAL_CHAR_SET="$CHAR_SET_STANDARD"

  # Check if special characters should be included
  if [[ "$INCLUDE_SPECIAL" -eq 1 ]]; then
    FINAL_CHAR_SET="$FINAL_CHAR_SET$CHAR_SET_SPECIAL"
  fi

  # Generate the string:
  local RANDOM_STRING

  # Use double quotes for the variable expansion in tr to correctly handle the escapes
  # The error will NOT appear if you use the corrected CHAR_SET_SPECIAL.
  RANDOM_STRING=$(< /dev/urandom tr -dc "$FINAL_CHAR_SET" | head -c "$LENGTH")

  # Output the generated string
  echo "$RANDOM_STRING"
}