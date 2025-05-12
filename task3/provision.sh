#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

VM_ID=$1
USERNAME="sftpuser"
USER_HOME="/home/${USERNAME}"
SHARED_DIR="/home/vagrant/shared"
PASSWORD=$(cat "$SHARED_DIR/password")

echo "Provisioning sftp${VM_ID}..."

echo "postfix postfix/main_mailer_type string 'No configuration'" | sudo debconf-set-selections
echo "postfix postfix/mailname string localhost" | sudo debconf-set-selections

if ! command -v rkhunter &> /dev/null; then
  echo "Installing rkhunter..."
  sudo apt update
  sudo apt install rkhunter -y

  sudo rkhunter --update
  sudo rkhunter --propupd

  echo "[PROVISION] rkhunter finish install"
else
  echo "[PROVISION] rkhunter already installed"
fi

echo "Creating user $USERNAME"
sudo adduser --gecos "" --quiet $USERNAME
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Creating .ssh/ directory for new user
sudo -u $USERNAME mkdir -p $USER_HOME/.ssh

# private key
sudo cp "$SHARED_DIR/sftp${VM_ID}_ed25519" "$USER_HOME/.ssh/id_ed25519"
sudo chmod 600 "$USER_HOME/.ssh/id_ed25519"
sudo chown $USERNAME:$USERNAME "$USER_HOME/.ssh/id_ed25519"

# authorized_keys
> /tmp/auth_keys
for i in 1 2 3; do
  if [ "$i" != "$VM_ID" ]; then
    cat "$SHARED_DIR/sftp${i}_ed25519.pub" >> /tmp/auth_keys
  fi
done

cat "$SHARED_DIR/ed25519.pub" >> /home/vagrant/.ssh/authorized_keys

sudo mv /tmp/auth_keys "$USER_HOME/.ssh/authorized_keys"
sudo chown $USERNAME:$USERNAME "$USER_HOME/.ssh/authorized_keys"
sudo chmod 600 "$USER_HOME/.ssh/authorized_keys"
sudo chmod 700 "$USER_HOME/.ssh"
sudo chmod 600 /home/vagrant/.ssh/authorized_keys
sudo chmod 700 /home/vagrant/.ssh

if [ "$VM_ID" != "1" ]; then
  sudo -u $USERNAME ssh-keyscan -H 192.168.56.101 >> /home/$USERNAME/.ssh/known_hosts
fi

# sftp for 1st vm (server)
if [ "$VM_ID" == "1" ]; then
  sudo mkdir -p $USER_HOME/temp
  sudo chown $USERNAME:$USERNAME $USER_HOME/temp
  sudo chmod 700 $USER_HOME/temp

  sshd_config
  CONFIG_BLOCK="Match User ${USERNAME}
    ForceCommand internal-sftp -d ${USER_HOME}/temp"
  if ! grep -q "Match User ${USERNAME}" /etc/ssh/sshd_config; then
    echo "$CONFIG_BLOCK" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    sudo systemctl restart sshd
  fi
fi

echo "Provisioning sftp${VM_ID} complete."