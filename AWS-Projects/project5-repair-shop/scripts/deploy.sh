#!/bin/bash

# Repair Shop Application Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"

echo -e "${GREEN}Starting Repair Shop Application Deployment...${NC}"

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

# Check if EB CLI is installed
if ! command -v eb &> /dev/null; then
    echo -e "${YELLOW}EB CLI is not installed. Installing...${NC}"
    pip install awsebcli
fi

echo -e "${YELLOW}Step 1: Deploying Infrastructure with Terraform...${NC}"
cd infrastructure
terraform init
terraform plan
terraform apply -auto-approve

# Get outputs from Terraform
DB_ENDPOINT=$(terraform output -raw db_endpoint)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
EB_URL=$(terraform output -raw elastic_beanstalk_url)

echo -e "${YELLOW}Step 2: Preparing Backend Application...${NC}"
cd ../backend

# Install dependencies
npm install

# Create .env file for local development
cat > .env << EOF
NODE_ENV=production
PORT=8080
DB_HOST=${DB_ENDPOINT}
DB_PORT=5432
DB_NAME=repairshop
DB_USER=repairshop_admin
DB_PASSWORD=RepairShop2024!
S3_BUCKET=${S3_BUCKET}
AWS_REGION=${AWS_REGION}
EOF

# Create deployment package
zip -r ../repair-shop-backend.zip . -x "node_modules/*" "*.git*" "*.env*"

echo -e "${YELLOW}Step 3: Deploying Backend to Elastic Beanstalk...${NC}"

# Initialize EB application if not already done
if [ ! -d ".elasticbeanstalk" ]; then
    eb init repair-shop-backend --region ${AWS_REGION} --platform "Node.js 18"
fi

# Deploy to EB
eb deploy --staged

echo -e "${YELLOW}Step 4: Preparing Frontend Application...${NC}"
cd ../frontend

# Install dependencies
npm install

# Create .env file for production
cat > .env.production << EOF
REACT_APP_API_URL=${EB_URL}
REACT_APP_ENVIRONMENT=production
EOF

# Build the application
npm run build

echo -e "${YELLOW}Step 5: Deploying Frontend to AWS Amplify...${NC}"

# Create Amplify app
AMPLIFY_APP_ID=$(aws amplify create-app \
    --name "repair-shop-frontend" \
    --description "Repair Shop Management System Frontend" \
    --platform "WEB" \
    --environment-variables REACT_APP_API_URL=${EB_URL} \
    --query 'app.appId' \
    --output text 2>/dev/null || echo "App already exists")

if [ "$AMPLIFY_APP_ID" = "App already exists" ]; then
    AMPLIFY_APP_ID=$(aws amplify list-apps --query 'apps[?name==`repair-shop-frontend`].appId' --output text)
fi

# Create branch
aws amplify create-branch \
    --app-id ${AMPLIFY_APP_ID} \
    --branch-name main \
    --description "Main branch" \
    --enable-auto-build

# Upload build files to S3
aws s3 sync build/ s3://${S3_BUCKET}/frontend/

echo -e "${YELLOW}Step 6: Setting up CloudFront Distribution...${NC}"

# Create CloudFront distribution
CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront create-distribution \
    --distribution-config '{
        "CallerReference": "'$(date +%s)'",
        "Comment": "Repair Shop Frontend Distribution",
        "DefaultRootObject": "index.html",
        "Origins": {
            "Quantity": 1,
            "Items": [
                {
                    "Id": "S3-'${S3_BUCKET}'",
                    "DomainName": "'${S3_BUCKET}'.s3.amazonaws.com",
                    "S3OriginConfig": {
                        "OriginAccessIdentity": ""
                    }
                }
            ]
        },
        "DefaultCacheBehavior": {
            "TargetOriginId": "S3-'${S3_BUCKET}'",
            "ViewerProtocolPolicy": "redirect-to-https",
            "TrustedSigners": {
                "Enabled": false,
                "Quantity": 0
            },
            "ForwardedValues": {
                "QueryString": false,
                "Cookies": {
                    "Forward": "none"
                }
            },
            "MinTTL": 0,
            "DefaultTTL": 86400,
            "MaxTTL": 31536000
        },
        "Enabled": true,
        "PriceClass": "PriceClass_100"
    }' \
    --query 'Distribution.Id' \
    --output text)

echo -e "${YELLOW}Step 7: Creating deployment documentation...${NC}"

# Create deployment guide
cat > ../DEPLOYMENT_GUIDE.md << EOF
# Repair Shop Application Deployment Guide

## Deployment Information
- **Backend URL**: ${EB_URL}
- **Database Endpoint**: ${DB_ENDPOINT}
- **S3 Bucket**: ${S3_BUCKET}
- **CloudFront Distribution**: ${CLOUDFRONT_DISTRIBUTION_ID}
- **AWS Region**: ${AWS_REGION}

## Application URLs
- **Backend API**: ${EB_URL}
- **Frontend**: https://${CLOUDFRONT_DISTRIBUTION_ID}.cloudfront.net
- **Health Check**: ${EB_URL}/health

## Database Connection
- **Host**: ${DB_ENDPOINT}
- **Port**: 5432
- **Database**: repairshop
- **Username**: repairshop_admin
- **Password**: RepairShop2024!

## Features Deployed
1. **Backend API** (Elastic Beanstalk)
   - Customer management
   - Repair tracking
   - Inventory management
   - User authentication
   - File upload to S3

2. **Frontend Application** (CloudFront + S3)
   - React-based user interface
   - Material-UI components
   - Responsive design
   - Real-time data updates

3. **Database** (RDS PostgreSQL)
   - Customer data
   - Repair records
   - Inventory items
   - User accounts

4. **File Storage** (S3)
   - Document uploads
   - Image storage
   - Backup files

## Access Information
- **Admin Username**: admin
- **Admin Password**: admin123

## Monitoring and Logs
- **Elastic Beanstalk Logs**: Available in AWS Console
- **CloudWatch Logs**: /aws/elasticbeanstalk/repair-shop-environment
- **RDS Logs**: Available in RDS Console

## Scaling Configuration
- **Auto Scaling**: 1-3 instances
- **Load Balancer**: Application Load Balancer
- **Health Checks**: /health endpoint

## Security Features
- **VPC**: Isolated network environment
- **Security Groups**: Restricted access
- **SSL/TLS**: HTTPS enabled
- **Database**: Encrypted at rest
- **S3**: Server-side encryption

## Backup and Recovery
- **Database**: Automated daily backups (7-day retention)
- **Application**: Blue/Green deployments
- **Files**: S3 versioning enabled

## Cost Optimization
- **Instance Types**: t3.micro for cost efficiency
- **Storage**: GP2 with auto-scaling
- **CDN**: CloudFront for global delivery
- **Monitoring**: CloudWatch for resource optimization
EOF

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Backend API URL: ${EB_URL}${NC}"
echo -e "${GREEN}Frontend URL: https://${CLOUDFRONT_DISTRIBUTION_ID}.cloudfront.net${NC}"
echo -e "${GREEN}Health Check: ${EB_URL}/health${NC}"
echo ""
echo -e "${YELLOW}Application Features:${NC}"
echo "- Customer Management System"
echo "- Repair Tracking and Status Updates"
echo "- Inventory Management with Low Stock Alerts"
echo "- User Authentication and Authorization"
echo "- File Upload and Document Management"
echo "- Responsive Web Interface"
echo "- Real-time Dashboard with Analytics"
echo ""
echo -e "${YELLOW}Access Information:${NC}"
echo "- Username: admin"
echo "- Password: admin123"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Access the application using the frontend URL"
echo "2. Log in with the provided credentials"
echo "3. Test all features and functionality"
echo "4. Monitor application performance in AWS Console"
echo "5. Set up additional monitoring and alerting as needed"
echo ""
echo -e "${YELLOW}Architecture Components:${NC}"
echo "- Frontend: React + Material-UI (CloudFront + S3)"
echo "- Backend: Node.js + Express (Elastic Beanstalk)"
echo "- Database: PostgreSQL (RDS)"
echo "- Storage: S3 for files and documents"
echo "- CDN: CloudFront for global content delivery"
echo "- Monitoring: CloudWatch for logs and metrics"
