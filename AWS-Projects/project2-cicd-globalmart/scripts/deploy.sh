#!/bin/bash

# GlobalMart CI/CD Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
S3_BUCKET="globalmart-codedeploy-$(openssl rand -hex 4)"
APPLICATION_NAME="globalmart-app"
DEPLOYMENT_GROUP="globalmart-dg"

echo -e "${GREEN}Starting GlobalMart CI/CD Deployment...${NC}"

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

echo -e "${YELLOW}Step 1: Deploying Infrastructure with Terraform...${NC}"
cd infrastructure
terraform init
terraform plan
terraform apply -auto-approve

# Get outputs from Terraform
ALB_DNS=$(terraform output -raw alb_dns_name)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
PIPELINE_NAME=$(terraform output -raw codepipeline_name)

echo -e "${YELLOW}Step 2: Creating deployment package...${NC}"
cd ../application
zip -r ../deployment.zip . -x "*.git*" "node_modules/.cache/*" "tests/*" "*.md"

echo -e "${YELLOW}Step 3: Uploading to S3...${NC}"
aws s3 cp ../deployment.zip s3://${S3_BUCKET}/source.zip

echo -e "${YELLOW}Step 4: Starting CodePipeline execution...${NC}"
aws codepipeline start-pipeline-execution --name ${PIPELINE_NAME}

echo -e "${YELLOW}Step 5: Monitoring deployment...${NC}"
echo "Waiting for deployment to complete..."

# Monitor pipeline execution
while true; do
    STATUS=$(aws codepipeline get-pipeline-execution \
        --pipeline-name ${PIPELINE_NAME} \
        --pipeline-execution-id $(aws codepipeline list-pipeline-executions \
            --pipeline-name ${PIPELINE_NAME} \
            --query 'pipelineExecutionSummaries[0].pipelineExecutionId' \
            --output text) \
        --query 'pipelineExecution.status' \
        --output text)
    
    echo "Pipeline status: $STATUS"
    
    if [ "$STATUS" = "Succeeded" ]; then
        echo -e "${GREEN}Deployment completed successfully!${NC}"
        break
    elif [ "$STATUS" = "Failed" ]; then
        echo -e "${RED}Deployment failed!${NC}"
        exit 1
    fi
    
    sleep 30
done

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Application URL: http://${ALB_DNS}${NC}"
echo -e "${GREEN}Health Check URL: http://${ALB_DNS}/health${NC}"
echo -e "${GREEN}API Endpoints:${NC}"
echo -e "  - Products: http://${ALB_DNS}/api/products"
echo -e "  - Categories: http://${ALB_DNS}/api/categories"
echo -e "  - Orders: http://${ALB_DNS}/api/orders"
