#!/bin/bash

# Script to prep Proxmox instance for K3s cluster

###############################################

# First set your password for your new user to be created
PASSWORD="<your-new-password-for-step-1A.3>"

###############################################

# install sudo as root
apt update > /dev/null 2>&1
apt install sudo -y

# For better security, create a separate Linux user instead of using root.
# You will also need to define a password for your ubuntu VMs on steps in Script 2.

# Note this is a user to the OS host running Proxmox, not the Proxmox UI, therefore you won't see this as an added user in the Proxmox UI
# Yes Proxmox is built on Debian linux. The user ubuntuprox was used because in Script 2 we'll be creating ubuntu VMs.

# Check if the password is the default one
if [ "$PASSWORD" = "<your-new-password-for-step-1A.3>" ]; then
  echo ""
  echo "Ubuntuprox user password is still set to default in script."
  echo "Please edit using nano 1A-init-proxmox-credentials-make-user.sh to set a custom password, then run script again."
  exit 1  # Exit the script with a non-zero status
else
  # Step 1A.1 Create the user with the default home directory location and bash shell.
  useradd -m -s /bin/bash ubuntuprox

  # Step 1A.2 Add them to the sudo group
  usermod -aG sudo ubuntuprox

  # Step 1A.3 Set a password for new user
  echo "ubuntuprox:$PASSWORD" | chpasswd

  echo ""
  echo "ubuntuprox user created. Switching to that user. Continue on to Script 1B."
  echo ""

  # Step 1A.4 switch user to ubuntuprox and download script 1B
  su - ubuntuprox -c "curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/0-1_ProxmoxSetup/1B-init-proxmox-credentials-make-ssh-keys.sh; chmod +x 1B-init-proxmox-credentials-make-ssh-keys.sh"

  # Step 1A.5 switch user to ubuntuprox and show what is in the home directory
  su - ubuntuprox -c "script -f /dev/null -q -c 'ls; bash'"
fi