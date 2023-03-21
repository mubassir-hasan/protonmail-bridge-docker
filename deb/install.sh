#!/bin/bash

set -ex

VERSION=`cat VERSION`
DEB_FILE=protonmail-bridge_${VERSION}_amd64.deb

# Install dependents
apt-get update
apt-get install -y --no-install-recommends socat pass  debsig-verify debian-keyring gdebi-core

# Build time dependencies
apt-get install -y wget 
8 | 4 | apt-get install gnome-keyring -y
mkdir  deb
cd deb
wget -q https://protonmail.com/download/bridge_pubkey.gpg
gpg --dearmor --output debsig.gpg bridge_pubkey.gpg
mkdir -p /usr/share/debsig/keyrings/E2C75D68E6234B07
mv debsig.gpg /usr/share/debsig/keyrings/E2C75D68E6234B07

wget -q https://protonmail.com/download/bridge.pol
mkdir -p /etc/debsig/policies/E2C75D68E6234B07
cp bridge.pol /etc/debsig/policies/E2C75D68E6234B07

wget -q https://protonmail.com/download/bridge/${DEB_FILE}
debsig-verify ${DEB_FILE}

gdebi ${DEB_FILE} -n

SERVICE_NAME="protonmail-service"

# Check if the service exists
if ! systemctl status $SERVICE_NAME &> /dev/null; then
  echo "Service $SERVICE_NAME does not exist. Creating service..."
  
  # Create the service file
  echo "[Unit]
  Description=Protonmail bridge service
  After=network.target

  [Service]
  Type=simple
  StandardOutput=journal
  ExecStart=/usr/bin/protonmail-bridge --noninteractive
  Restart=always

  [Install]
  WantedBy=multi-user.target" > /etc/systemd/system/$SERVICE_NAME.service

  # Reload the systemd daemon
  systemctl daemon-reload

  # Enable and start the service
  systemctl enable $SERVICE_NAME
  systemctl start $SERVICE_NAME
  
  echo "Service $SERVICE_NAME created and started."
else
  echo "Service $SERVICE_NAME already exists."
fi

# Cleanup
apt-get purge -y wget 
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
rm -rf deb
