#!/bin/bash

# After Install Script for GlobalMart Application
set -e

echo "Starting after install script..."

# Set proper permissions
echo "Setting permissions..."
chown -R ec2-user:ec2-user /opt/globalmart
chmod +x /opt/globalmart/scripts/*.sh

# Install dependencies
echo "Installing Node.js dependencies..."
cd /opt/globalmart
sudo -u ec2-user npm install --production

# Update environment file if needed
if [ ! -f "/opt/globalmart/.env" ]; then
    echo "Creating environment file..."
    cat > /opt/globalmart/.env << EOF
NODE_ENV=production
PORT=3000
DB_HOST=localhost
DB_PORT=3306
DB_NAME=globalmart
DB_USER=admin
DB_PASSWORD=GlobalMart2024!
JWT_SECRET=globalmart_jwt_secret_2024
APP_NAME=GlobalMart
APP_VERSION=1.0.0
EOF
    chown ec2-user:ec2-user /opt/globalmart/.env
fi

# Create log directory if it doesn't exist
mkdir -p /var/log/globalmart
chown ec2-user:ec2-user /var/log/globalmart

echo "After install script completed successfully"
