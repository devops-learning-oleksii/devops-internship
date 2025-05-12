#!/bin/bash

LOG_FILE="/home/appuser/logs/ssh_logs.log"
SSH_KEY="/home/appuser/.ssh/ed25519"
USER="vagrant"

mkdir -p /home/appuser/logs

touch "$LOG_FILE"

for ip_suffix in 1 2 3; do
    IP="192.168.56.10${ip_suffix}"

    ssh -i "$SSH_KEY" "$USER@$IP" "sudo journalctl -u ssh | grep 'Accepted'" >> "$LOG_FILE" 2>/dev/null

    ssh -i "$SSH_KEY" "$USER@$IP" "sudo journalctl --rotate && sudo journalctl --vacuum-time=1s" >/dev/null 2>&1
done

echo "Logs have been appended to $LOG_FILE"