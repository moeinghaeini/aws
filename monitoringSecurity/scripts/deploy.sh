#!/bin/bash

# Monitoring & Security Auto-Remediation Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"

echo -e "${GREEN}Starting Monitoring & Security Auto-Remediation Deployment...${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed. Please install it first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Preparing Lambda functions...${NC}"
cd lambda_functions

# Create zip files for Lambda functions
for func_dir in */; do
    if [ -d "$func_dir" ]; then
        func_name=$(basename "$func_dir")
        echo "Packaging Lambda function: $func_name"
        cd "$func_name"
        zip -r "../${func_name}.zip" .
        cd ..
    fi
done

cd ..

echo -e "${YELLOW}Step 2: Deploying Infrastructure with Terraform...${NC}"
cd infrastructure
terraform init
terraform plan
terraform apply -auto-approve

# Get outputs from Terraform
INSTANCE_ID=$(terraform output -raw instance_id)
DASHBOARD_URL=$(terraform output -raw dashboard_url)
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)

echo -e "${YELLOW}Step 3: Setting up monitoring and security services...${NC}"

# Enable GuardDuty
echo "Enabling GuardDuty..."
aws guardduty create-detector --enable

# Enable Security Hub
echo "Enabling Security Hub..."
aws securityhub enable-security-hub --enable-default-standards

# Enable Config
echo "Enabling Config..."
aws configservice put-configuration-recorder --configuration-recorder name=default,roleARN=$(aws iam get-role --role-name config-role --query 'Role.Arn' --output text 2>/dev/null || echo "Config role not found")

echo -e "${YELLOW}Step 4: Setting up CloudWatch alarms...${NC}"

# Create additional custom alarms
aws cloudwatch put-metric-alarm \
    --alarm-name "monitoring-application-response-time" \
    --alarm-description "Application response time is too high" \
    --metric-name "ResponseTime" \
    --namespace "Custom/Application" \
    --statistic "Average" \
    --period 300 \
    --threshold 2.0 \
    --comparison-operator "GreaterThanThreshold" \
    --evaluation-periods 2 \
    --alarm-actions "$SNS_TOPIC_ARN"

echo -e "${YELLOW}Step 5: Testing the monitoring system...${NC}"

# Test the monitoring system by generating some load
echo "Generating test load on the monitored instance..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["for i in {1..10}; do curl -s http://localhost/ > /dev/null; sleep 1; done"]'

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Monitoring Dashboard: ${DASHBOARD_URL}${NC}"
echo -e "${GREEN}Monitored Instance ID: ${INSTANCE_ID}${NC}"
echo -e "${GREEN}SNS Topic ARN: ${SNS_TOPIC_ARN}${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Subscribe to the SNS topic to receive alerts"
echo "2. Review the CloudWatch dashboard for monitoring metrics"
echo "3. Test the auto-remediation functions by triggering alarms"
echo "4. Configure additional monitoring rules as needed"
echo ""
echo -e "${YELLOW}Available Auto-Remediation Actions:${NC}"
echo "- High CPU: Restart Apache service"
echo "- High Memory: Clear system cache"
echo "- Disk Space: Clean up log files"
echo "- Instance Status: Reboot instance"
echo "- Security Threats: Isolate compromised resources"
echo "- Compliance Violations: Auto-remediate security groups, S3 buckets, etc."
echo "- Cost Optimization: Identify idle resources and cost-saving opportunities"
