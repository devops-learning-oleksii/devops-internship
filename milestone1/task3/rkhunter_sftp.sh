#!/bin/bash

LOG_DIR="/var/log"
RKHUNTER_LOG="$LOG_DIR/rkhunter.log"
HOST_INDEX=$1
USERNAME="sftpuser"
USER_HOME="/home/${USERNAME}"
TIMESTAMP=$(date +"%y:%m:%d_%H:%M:%S")
NEW_LOG_NAME="sftp${HOST_INDEX}_${TIMESTAMP}_rkhunter.log"
RENAMED_LOG_PATH="$LOG_DIR/$NEW_LOG_NAME"
DEST_PATH="/home/${USERNAME}/temp/"

if [[ -z "$HOST_INDEX" ]]; then
  echo "Error: missing host index (expected as first argument)"
  exit 1
fi

rkhunter --check --sk > "$RKHUNTER_LOG"

mv "$RKHUNTER_LOG" "$RENAMED_LOG_PATH"

sudo chown $USERNAME:$USERNAME "$RENAMED_LOG_PATH"

if [[ "$HOST_INDEX" == "1" ]]; then
  mv "$RENAMED_LOG_PATH" "$DEST_PATH"
else
  sudo -u $USERNAME sftp sftpuser@192.168.56.101 <<< "put $RENAMED_LOG_PATH"
  sudo rm $RENAMED_LOG_PATH
fi