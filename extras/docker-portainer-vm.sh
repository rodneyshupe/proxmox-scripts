sudo apt-get update
sudo apt-get install jq cifs-utils nfs-kernel-server -y -qq

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

sudo apt-get install docker-compose

sudo mkdir -p /srv/appdate/traefik/letsencrypt
sudo mkdir -p /srv/appdate/homer
sudo mkdir -p /srv/appdate/heimdall
sudo mkdir -p /mnt/appdata
sudo mkdir -p /mnt/storage
sudo mkdir -p /mnt/media
sudo mkdir -p /mnt/downloads

echo "192.168.27.16:/appdata    /mnt/appdata          nfs   defaults              0  0" | sudo tee -a /etc/fstab
echo "192.168.27.16:/downloads  /mnt/downloads        nfs   defaults              0  0" | sudo tee -a /etc/fstab
echo "192.168.27.16:/storage    /mnt/storage          nfs   defaults              0  0" | sudo tee -a /etc/fstab
echo "192.168.27.16:/media      /mnt/media            nfs   defaults              0  0" | sudo tee -a /etc/fstab


# aUZqdXE3SGF2N3VaV3FBN2RNWmw3UQ==