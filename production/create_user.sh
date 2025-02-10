#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Prompt for the new username
read -p "Enter the username to create: " USERNAME

# Create the user and set a password
adduser --gecos "" $USERNAME

# Add the user to the sudo group
usermod -aG sudo $USERNAME
echo "User $USERNAME added to the sudo group."

# Create the .ssh directory for the new user
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
mkdir -p $SSH_DIR
chmod 700 $SSH_DIR
chown $USERNAME:$USERNAME $SSH_DIR
echo "Created .ssh directory for $USERNAME."

# Prompt for SSH public key
read -p "Paste the SSH public key for the user: " SSH_KEY

# Add the SSH public key to the authorized_keys file
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
echo $SSH_KEY > $AUTHORIZED_KEYS
chmod 600 $AUTHORIZED_KEYS
chown $USERNAME:$USERNAME $AUTHORIZED_KEYS
echo "SSH key added for $USERNAME."

# Ensure SSH key-based authentication is enabled
SSH_CONFIG="/etc/ssh/sshd_config"
if ! grep -q "^PubkeyAuthentication yes" $SSH_CONFIG; then
  echo "Enabling public key authentication in $SSH_CONFIG..."
  sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' $SSH_CONFIG
fi

if ! grep -q "^AuthorizedKeysFile" $SSH_CONFIG; then
  echo "Setting authorized keys file configuration in $SSH_CONFIG..."
  echo "AuthorizedKeysFile .ssh/authorized_keys" >> $SSH_CONFIG
fi

# Restart SSH service to apply changes
systemctl restart ssh
echo "SSH configuration updated and service restarted."

usermod -aG docker $USERNAME

echo "User $USERNAME has been successfully created with sudo privileges and SSH key access."