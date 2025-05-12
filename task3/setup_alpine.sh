#!/bin/sh

apk update && apk upgrade
apk add docker python3 py3-pip openssh
apk add docker-compose

rc-update add docker default
rc-update add sshd default

rc-service docker start
rc-service sshd start

SHARED_DIR="/home/vagrant/shared"
PASSWORD=$(cat "$SHARED_DIR/password")
USER="appuser"
adduser -D $USER
echo "$USER:$PASSWORD" | chpasswd
sudo -u $USER ssh-keygen -t ed25519 -f /home/$USER/.ssh/ed25519 -N ""

mkdir -p /home/vagrant/shared
cp /home/$USER/.ssh/ed25519.pub /home/vagrant/shared/ed25519.pub

chown -R $USER:$USER /home/$USER/.ssh
chmod 700 /home/$USER/.ssh
chmod 600 /home/$USER/.ssh/ed25519
chmod 644 /home/$USER/.ssh/ed25519.pub

chmod 644 /home/$USER/.ssh/known_hosts
chown $USER:$USER /home/$USER/.ssh/known_hosts

mkdir /home/$USER/scripts
cp /home/vagrant/shared/get_logs.sh /home/$USER/scripts
chown $USER:$USER /home/$USER/scripts/get_logs.sh

CRON_JOB="0 * * * * /home/$USER/scripts/get_logs.sh"
CRON_FILE="/var/spool/cron/crontabs/$USER"

echo "$CRON_JOB" >> "$CRON_FILE"
chown $USER:root "$CRON_FILE"
chmod 600 "$CRON_FILE"

cp -R /home/vagrant/shared/app /home/$USER/
chown -R $USER:$USER /home/$USER/app

cp /home/vagrant/shared/alpine_ssh.sh /home/$USER/scripts
chown $USER:$USER /home/$USER/scripts/alpine_ssh.sh
# passwd appuser -d "123"

pip3 install pymongo

addgroup docker || true
addgroup $USER docker
adduser $USER docker
#sudo docker run -d --name mongodb -p 27017:27017 mongo:4.4