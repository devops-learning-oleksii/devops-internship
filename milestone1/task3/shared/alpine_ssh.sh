#!/bin/sh

USER="appuser"
for ip in 192.168.56.101 192.168.56.102 192.168.56.103; do
    ssh-keyscan -H $ip >> /home/$USER/.ssh/known_hosts
done