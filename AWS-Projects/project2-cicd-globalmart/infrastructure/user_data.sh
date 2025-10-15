#!/bin/bash

# Update system
yum update -y

# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install PM2 globally
npm install -g pm2

# Install CodeDeploy agent
yum install -y ruby
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
service codedeploy-agent start

# Create application directory
mkdir -p /opt/globalmart
chown ec2-user:ec2-user /opt/globalmart

# Create environment file
cat > /opt/globalmart/.env << EOF
NODE_ENV=production
PORT=3000
DB_HOST=${db_endpoint}
DB_PORT=3306
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
JWT_SECRET=globalmart_jwt_secret_2024
APP_NAME=GlobalMart
APP_VERSION=1.0.0
EOF

# Create PM2 ecosystem file
cat > /opt/globalmart/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'globalmart',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/globalmart/err.log',
    out_file: '/var/log/globalmart/out.log',
    log_file: '/var/log/globalmart/combined.log',
    time: true
  }]
};
EOF

# Create log directory
mkdir -p /var/log/globalmart
chown ec2-user:ec2-user /var/log/globalmart

# Create systemd service for PM2
cat > /etc/systemd/system/globalmart.service << EOF
[Unit]
Description=GlobalMart E-Commerce Application
After=network.target

[Service]
Type=forking
User=ec2-user
WorkingDirectory=/opt/globalmart
ExecStart=/usr/bin/pm2 start ecosystem.config.js
ExecReload=/usr/bin/pm2 reload ecosystem.config.js
ExecStop=/usr/bin/pm2 stop ecosystem.config.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl enable globalmart.service

# Create health check script
cat > /opt/globalmart/health_check.sh << EOF
#!/bin/bash
curl -f http://localhost:3000/health || exit 1
EOF

chmod +x /opt/globalmart/health_check.sh

# Set up log rotation
cat > /etc/logrotate.d/globalmart << EOF
/var/log/globalmart/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 ec2-user ec2-user
    postrotate
        /usr/bin/pm2 reloadLogs
    endscript
}
EOF

echo "User data script completed successfully"
