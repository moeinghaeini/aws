#!/bin/bash

# Before Install Script for GlobalMart Application
set -e

echo "Starting before install script..."

# Stop the application if it's running
if systemctl is-active --quiet globalmart; then
    echo "Stopping existing GlobalMart service..."
    systemctl stop globalmart
fi

# Kill any existing PM2 processes
if command -v pm2 &> /dev/null; then
    echo "Stopping existing PM2 processes..."
    pm2 stop all || true
    pm2 delete all || true
fi

# Create backup of current application
if [ -d "/opt/globalmart" ]; then
    echo "Creating backup of current application..."
    cp -r /opt/globalmart /opt/globalmart.backup.$(date +%Y%m%d_%H%M%S) || true
fi

# Clean up old backups (keep only last 3)
echo "Cleaning up old backups..."
ls -t /opt/globalmart.backup.* 2>/dev/null | tail -n +4 | xargs rm -rf || true

echo "Before install script completed successfully"
