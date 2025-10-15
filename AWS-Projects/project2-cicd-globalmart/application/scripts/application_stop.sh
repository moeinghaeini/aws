#!/bin/bash

# Application Stop Script for GlobalMart Application
set -e

echo "Starting application stop script..."

# Stop PM2 processes
echo "Stopping PM2 processes..."
if command -v pm2 &> /dev/null; then
    sudo -u ec2-user pm2 stop all || true
    sudo -u ec2-user pm2 delete all || true
fi

# Stop systemd service if it exists
if systemctl is-active --quiet globalmart; then
    echo "Stopping GlobalMart systemd service..."
    systemctl stop globalmart || true
fi

# Kill any remaining Node.js processes
echo "Killing any remaining Node.js processes..."
pkill -f "node.*server.js" || true

# Wait a moment for processes to terminate
sleep 5

echo "Application stop script completed successfully"
