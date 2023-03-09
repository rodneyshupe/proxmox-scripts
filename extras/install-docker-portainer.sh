#!/usr/bin/env bash

#######################################################################
##                                                                   ##
## Setup Script for installing Docke, Portainer and related scripts  ##
## and enviorment such as directory including mounts                 ##
##                                                                   ##
## This assumes you have setup a TurnKey-Core LCX container and this ##
## will be run on that container                                     ##
##                                                                   ##
## Other assuptions:                                                 ##
##     Data will be stored at /srv/appdata                           ##
##     App data backups will be at /mnt/appdata                      ##
##                                                                   ##
#######################################################################

# Debian Install for Docker
# Reference: https://docs.docker.com/engine/install/debian/

echo "Step 1: Setup Enviorment"

echo "  Install dependancies..."
sudo apt-get update -qq
sudo apt-get install jq cifs-utils -y -q -q -q
mount -t cifs //192.168.27.16/appdata username=milliways,password=K1effer*%^!,workgroup=WORKGROUP /mnt/appdata
#//WinPC/share /media/win-share cifs username=Win-user,password=pass,workgroup=WORKGROUP 0 0

echo "  Ensure Turnkey Services are running..."
sudo service stunnel4@webmin enable
sudo service stunnel4@webmin start
#sudo service stunnel4@shellinabox enable
#sudo service stunnel4@shellinabox start

echo "  Create directories..."
sudo mkdir -p /srv/appdata
sudo mkdir -p /mnt/appdata
mkdir -p $HOME/.scripts
mkdir -p $HOME/.config

echo "  Get Scripts..."

echo "  Install crontab..."


echo "Step 1: Set up the repository"

echo "  Install dependancies..."
sudo apt-get update -qq
sudo apt-get install ca-certificates curl gnupg lsb-release -y -qqq

echo "  Add Docker’s official GPG key..."
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "  Set sources file..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo
echo "Step 2: Install Docker Engine"
echo "  Update the apt package index..."
sudo apt-get update -qq

echo "  Install Docker Engine, containerd, and Docker Compose..."
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y -qqq

echo "  Add docker group"
sudo groupadd docker

echo 
echo "Installation complete."
echo
echo "Test using:"
echo "  sudo docker run hello-world"
echo
echo

# Create AppData location
mkdir -p /srv/appdata

# Setup Portainer
# Reference: https://docs.docker.com/engine/install/debian/

echo "Setup Portainer"

echo
echo "  Create volume for portainer data"
docker volume create portainer_data

echo "  Start Portainer"
docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

