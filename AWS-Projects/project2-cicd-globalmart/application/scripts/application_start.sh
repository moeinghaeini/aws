#!/bin/bash

# Application Start Script for GlobalMart Application
set -e

echo "Starting application start script..."

# Start the application using PM2
echo "Starting GlobalMart application with PM2..."
cd /opt/globalmart
sudo -u ec2-user pm2 start ecosystem.config.js

# Save PM2 configuration
sudo -u ec2-user pm2 save

# Setup PM2 startup script
sudo -u ec2-user pm2 startup systemd -u ec2-user --hp /home/ec2-user

# Wait for application to start
echo "Waiting for application to start..."
sleep 10

# Health check
echo "Performing health check..."
for i in {1..30}; do
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        echo "Application is healthy!"
        break
    fi
    echo "Health check attempt $i failed, retrying in 5 seconds..."
    sleep 5
done

# Final health check
if ! curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "ERROR: Application failed to start properly"
    exit 1
fi

echo "Application start script completed successfully"
