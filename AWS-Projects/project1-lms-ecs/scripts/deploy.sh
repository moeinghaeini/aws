#!/bin/bash

# LMS ECS Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
ECR_REPO_NAME="lms-frontend"
ECS_CLUSTER_NAME="lms-cluster"
ECS_SERVICE_NAME="lms-service"

echo -e "${GREEN}Starting LMS ECS Deployment...${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install it first.${NC}"
    exit 1
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo -e "${YELLOW}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${YELLOW}ECR URI: ${ECR_URI}${NC}"

# Step 1: Build Docker image
echo -e "${GREEN}Step 1: Building Docker image...${NC}"
docker build -t ${ECR_REPO_NAME}:latest .

# Step 2: Login to ECR
echo -e "${GREEN}Step 2: Logging into ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

# Step 3: Tag and push image
echo -e "${GREEN}Step 3: Tagging and pushing image to ECR...${NC}"
docker tag ${ECR_REPO_NAME}:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest

# Step 4: Update ECS service
echo -e "${GREEN}Step 4: Updating ECS service...${NC}"
aws ecs update-service \
    --cluster ${ECS_CLUSTER_NAME} \
    --service ${ECS_SERVICE_NAME} \
    --force-new-deployment \
    --region ${AWS_REGION}

# Step 5: Wait for deployment to complete
echo -e "${GREEN}Step 5: Waiting for deployment to complete...${NC}"
aws ecs wait services-stable \
    --cluster ${ECS_CLUSTER_NAME} \
    --services ${ECS_SERVICE_NAME} \
    --region ${AWS_REGION}

# Step 6: Get ALB DNS name
echo -e "${GREEN}Step 6: Getting ALB DNS name...${NC}"
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?contains(LoadBalancerName, `lms-alb`)].DNSName' \
    --output text \
    --region ${AWS_REGION})

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Application URL: http://${ALB_DNS}${NC}"
echo -e "${GREEN}Health Check URL: http://${ALB_DNS}/health${NC}"
