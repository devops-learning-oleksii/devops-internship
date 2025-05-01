#!/bin/bash

VM_ID=$1
USERNAME="sftpuser"
USER_HOME="/home/${USERNAME}"
SHARED_DIR="/home/vagrant/shared"

echo "Provisioning sftp${VM_ID}..."

sudo adduser --disabled-password --gecos "" $USERNAME

sudo -u $USERNAME mkdir -p $USER_HOME/.ssh

sudo cp $SHARED_DIR/id_ed25519 $USER_HOME/.ssh/id_ed25519
sudo chmod 600 $USER_HOME/.ssh/id_ed25519

if [ -f "$SHARED_DIR/id_ed25519_${VM_ID}.pub" ]; then
  sudo cp $SHARED_DIR/id_ed25519_${VM_ID}.pub $USER_HOME/.ssh/id_ed25519.pub
  sudo chmod 644 $USER_HOME/.ssh/id_ed25519.pub
fi

> /tmp/auth_keys
for i in 1 2 3; do
  if [ "$i" != "$VM_ID" ]; then
    cat "$SHARED_DIR/id_ed25519_${i}.pub" >> /tmp/auth_keys
  fi
done

sudo mv /tmp/auth_keys $USER_HOME/.ssh/authorized_keys
sudo chown $USERNAME:$USERNAME -R $USER_HOME/.ssh
sudo chmod 600 $USER_HOME/.ssh/authorized_keys
sudo chmod 700 $USER_HOME/.ssh

echo "Provisioning sftp${VM_ID} complete."