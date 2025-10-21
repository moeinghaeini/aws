#!/bin/bash

# Update system
yum update -y

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Install SSM agent (usually pre-installed on Amazon Linux 2)
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time",
                    "read_bytes",
                    "write_bytes",
                    "reads",
                    "writes"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "${log_group_name}",
                        "log_stream_name": "{instance_id}/messages"
                    },
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "${log_group_name}",
                        "log_stream_name": "{instance_id}/secure"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Create a simple web application for monitoring
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Monitoring Test Application</title>
</head>
<body>
    <h1>Monitoring Test Application</h1>
    <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
    <p>Timestamp: $(date)</p>
    <p>Status: Healthy</p>
</body>
</html>
EOF

# Install and start Apache
yum install -y httpd
systemctl enable httpd
systemctl start httpd

# Create monitoring script
cat > /usr/local/bin/monitoring.sh << 'EOF'
#!/bin/bash

# Custom metrics collection script
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Get memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')

# Get disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

# Get load average
LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)

# Send custom metrics to CloudWatch
aws cloudwatch put-metric-data \
    --namespace "Custom/EC2" \
    --metric-data MetricName=MemoryUtilization,Value=$MEMORY_USAGE,Unit=Percent \
    --region $REGION

aws cloudwatch put-metric-data \
    --namespace "Custom/EC2" \
    --metric-data MetricName=DiskUtilization,Value=$DISK_USAGE,Unit=Percent \
    --region $REGION

aws cloudwatch put-metric-data \
    --namespace "Custom/EC2" \
    --metric-data MetricName=LoadAverage,Value=$LOAD_AVERAGE,Unit=None \
    --region $REGION

echo "$(date): Metrics sent - Memory: $MEMORY_USAGE%, Disk: $DISK_USAGE%, Load: $LOAD_AVERAGE"
EOF

chmod +x /usr/local/bin/monitoring.sh

# Add monitoring script to crontab
echo "*/5 * * * * /usr/local/bin/monitoring.sh >> /var/log/monitoring.log 2>&1" | crontab -

# Create log rotation for monitoring logs
cat > /etc/logrotate.d/monitoring << EOF
/var/log/monitoring.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

echo "User data script completed successfully"
