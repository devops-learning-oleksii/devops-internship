#!/bin/sh

User="appuser"
for ip in 192.168.56.101 192.168.56.102 192.168.56.103; do
    sudo -u $User ssh-keyscan -H $ip >> /home/$User/.ssh/known_hosts
done