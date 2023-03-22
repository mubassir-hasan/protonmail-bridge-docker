#!/bin/bash

set -ex

VERSION=`cat VERSION`
DEB_FILE=protonmail-bridge_${VERSION}_amd64.deb

# Install dependents
apt-get update
apt-get install -y --no-install-recommends socat pass  debsig-verify debian-keyring gdebi-core

# Build time dependencies
apt-get install -y wget dbus-x11
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



# Cleanup
apt-get purge -y wget 
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
rm -rf deb
