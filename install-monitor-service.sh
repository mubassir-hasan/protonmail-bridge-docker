#!/bin/bash
# Installation script for Protonmail Bridge Monitor Service
# Run with: sudo bash install-monitor-service.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Protonmail Bridge Monitor Service..."

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo: sudo bash $0"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

# Check if cicd_user exists
if ! id "cicd_user" &>/dev/null; then
    echo "Error: User 'cicd_user' does not exist"
    echo "Please create the user or modify the service file with the correct username"
    exit 1
fi

# Check if cicd_user is in docker group
if ! groups cicd_user | grep -q docker; then
    echo "Warning: User 'cicd_user' is not in the docker group"
    echo "Adding cicd_user to docker group..."
    usermod -aG docker cicd_user
fi

# Copy monitoring script
echo "Copying monitoring script to /usr/local/bin/..."
cp "$SCRIPT_DIR/protonmail-monitor.sh" /usr/local/bin/
chmod +x /usr/local/bin/protonmail-monitor.sh

# Copy systemd service
echo "Copying systemd service to /etc/systemd/system/..."
cp "$SCRIPT_DIR/protonmail-monitor.service" /etc/systemd/system/

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable and start service
echo "Enabling and starting protonmail-monitor service..."
systemctl enable protonmail-monitor
systemctl start protonmail-monitor

echo ""
echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "Useful commands:"
echo "  Check status:  systemctl status protonmail-monitor"
echo "  View logs:     journalctl -u protonmail-monitor -f"
echo "  Stop service:  systemctl stop protonmail-monitor"
echo "  Start service: systemctl start protonmail-monitor"
echo "  Disable:       systemctl disable protonmail-monitor"
echo ""
echo "The service will automatically start on boot."
