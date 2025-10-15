# AWS Cloud Projects Collection

This repository contains 5 comprehensive AWS cloud projects that demonstrate various AWS services, architectures, and best practices for cloud deployment and management.

## 🚀 Project Overview

### Project 1: Containerized LMS Migration and Troubleshooting
**Location**: `AWS-Projects/project1-lms-ecs/`
**Technologies**: ECS Fargate, ALB, VPC, ECR, CloudWatch
**Description**: A complete Learning Management System deployed on AWS ECS Fargate with Application Load Balancer, including troubleshooting scenarios and solutions.

### Project 2: CI/CD Pipeline for GlobalMart E-Commerce Platform
**Location**: `AWS-Projects/project2-cicd-globalmart/`
**Technologies**: CodePipeline, CodeDeploy, EC2, Auto Scaling, RDS
**Description**: A complete CI/CD pipeline for an e-commerce platform with automated testing, deployment, and scaling capabilities.

### Project 3: Proactive Monitoring & Security Auto-Remediation
**Location**: `AWS-Projects/project3-monitoring-security/`
**Technologies**: CloudWatch, Lambda, GuardDuty, Security Hub, EventBridge
**Description**: A comprehensive monitoring and security auto-remediation system that proactively responds to threats and performance issues.

### Project 4: Debugging a Broken Serverless Contact Form Workflow
**Location**: `AWS-Projects/project4-serverless-contact/`
**Technologies**: Lambda, API Gateway, S3, DynamoDB, SNS
**Description**: A serverless contact form application with intentional issues for debugging practice, demonstrating troubleshooting techniques.

### Project 5: Repair Shop Application Deployment on AWS
**Location**: `AWS-Projects/project5-repair-shop/`
**Technologies**: Elastic Beanstalk, Amplify, RDS, S3, CloudFront
**Description**: A complete repair shop management system with customer management, repair tracking, and inventory management.

## 🏗️ Architecture Patterns Demonstrated

- **Container Orchestration** (ECS Fargate)
- **CI/CD and DevOps** (CodePipeline, CodeDeploy)
- **Monitoring and Security** (CloudWatch, Lambda automation)
- **Serverless Architecture** (Lambda, API Gateway)
- **Full-Stack Applications** (Elastic Beanstalk, RDS)

## 🛠️ AWS Services Used

### Compute
- EC2, ECS Fargate, Lambda, Elastic Beanstalk

### Storage
- S3, EBS, EFS

### Database
- RDS (MySQL, PostgreSQL), DynamoDB

### Networking
- VPC, ALB, CloudFront, Route 53

### Security
- IAM, GuardDuty, Security Hub, Config

### Monitoring
- CloudWatch, X-Ray, EventBridge

### DevOps
- CodePipeline, CodeDeploy, CodeBuild

## 🚀 Getting Started

Each project includes:
- Complete source code
- Infrastructure as Code (Terraform)
- Automated deployment scripts
- Comprehensive documentation
- Troubleshooting guides

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.6 installed
- Node.js >= 18 and npm >= 9 (for application projects)
- Docker (for containerized projects)
- Python 3.11+ (for Lambda functions)

### Quick Start
1. Navigate to any project directory
2. Review the README.md for specific instructions
3. Run the deployment script: `./scripts/deploy.sh`
4. Follow the post-deployment instructions

## 📚 Learning Outcomes

After completing these projects, you will understand:

1. **Container Orchestration**: How to deploy and manage containerized applications on AWS
2. **CI/CD Pipelines**: Building automated deployment pipelines for continuous delivery
3. **Monitoring and Security**: Implementing comprehensive monitoring and automated security responses
4. **Serverless Architecture**: Building and debugging serverless applications
5. **Full-Stack Deployment**: Deploying complete applications with frontend, backend, and database

## 💰 Cost Considerations

Each project is designed to use minimal AWS resources to keep costs low:
- t3.micro instances for compute
- db.t3.micro for databases
- Minimal storage configurations
- Auto-scaling to scale down when not in use
- Latest AWS services for optimal performance and cost efficiency

Estimated monthly cost per project: $10-30 (depending on usage)

## 🔄 Recent Updates (October 2025)

- **Dependencies Updated**: All projects now use the latest stable versions
  - React 18.3.1 with latest security patches
  - Node.js 20 LTS for better performance
  - AWS SDK v3 for improved performance and security
  - Terraform 1.6+ with latest AWS provider
  - Python 3.11 for Lambda functions
- **Security Enhancements**: Updated all packages to address security vulnerabilities
- **Performance Improvements**: Migrated to AWS SDK v3 for better performance
- **Infrastructure Updates**: Latest Terraform configurations with improved security

## 📖 Documentation

Each project includes comprehensive documentation:
- Deployment guides
- Troubleshooting documentation
- Architecture diagrams
- Best practices

## 🤝 Contributing

These projects are designed for learning and demonstration purposes. Feel free to:
- Modify and extend the functionality
- Add new features
- Improve the documentation
- Share your improvements

## 📄 License

This project collection is provided for educational purposes. Please ensure you understand AWS pricing and terms of service before deploying to production environments.

---

**Happy Learning! 🚀**

For questions or support, please refer to the individual project documentation or AWS documentation.
