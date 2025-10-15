#!/bin/bash

# AWS Projects Git Setup Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Git repository for AWS Projects...${NC}"

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git is not installed. Please install Git first.${NC}"
    exit 1
fi

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Initializing Git repository...${NC}"
    git init
else
    echo -e "${YELLOW}Git repository already initialized.${NC}"
fi

# Add remote origin
echo -e "${YELLOW}Setting up remote origin...${NC}"
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/moeinghaeini/aws.git

# Add all files
echo -e "${YELLOW}Adding files to Git...${NC}"
git add .

# Commit changes
echo -e "${YELLOW}Committing changes...${NC}"
git commit -m "Initial commit: AWS Cloud Projects Collection

- Project 1: Containerized LMS Migration and Troubleshooting (ECS Fargate)
- Project 2: CI/CD Pipeline for GlobalMart E-Commerce Platform
- Project 3: Proactive Monitoring & Security Auto-Remediation
- Project 4: Debugging a Broken Serverless Contact Form Workflow
- Project 5: Repair Shop Application Deployment on AWS

Each project includes:
- Complete source code
- Infrastructure as Code (Terraform)
- Automated deployment scripts
- Comprehensive documentation
- Troubleshooting guides

Technologies used: ECS, Lambda, API Gateway, RDS, S3, CloudWatch, CodePipeline, Elastic Beanstalk, and more."

# Push to GitHub
echo -e "${YELLOW}Pushing to GitHub...${NC}"
git branch -M main
git push -u origin main

echo -e "${GREEN}Successfully pushed AWS Projects to GitHub!${NC}"
echo -e "${GREEN}Repository URL: https://github.com/moeinghaeini/aws${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Visit your repository at https://github.com/moeinghaeini/aws"
echo "2. Review the projects and documentation"
echo "3. Deploy any project using the provided deployment scripts"
echo "4. Share your repository with others for learning purposes"
