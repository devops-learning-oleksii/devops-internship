#!/bin/bash

HOST_INDEX=$1
SCRIPT_NAME="rkhunter_sftp.sh"
SCRIPT_SRC="/vagrant/${SCRIPT_NAME}"
SCRIPT_DEST="/usr/local/bin/${SCRIPT_NAME}"
SERVICE_NAME="rkhunter-sftp.service"
TIMER_NAME="rkhunter-sftp.timer"

sudo cp "$SCRIPT_SRC" "$SCRIPT_DEST"
sudo chmod +x "$SCRIPT_DEST"

cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME
[Unit]
Description=Run rkhunter sftp sync script
After=network.target

[Service]
Type=oneshot
User=vagrant
ExecStart=/usr/bin/sudo $SCRIPT_DEST $HOST_INDEX
EOF

cat <<EOF | sudo tee /etc/systemd/system/$TIMER_NAME
[Unit]
Description=Run rkhunter sftp sync every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=$SERVICE_NAME

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now $TIMER_NAME