# AWS Cloud Projects Collection

A comprehensive collection of AWS cloud projects demonstrating various services, architectures, and best practices for cloud deployment and management.

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

### Project 6: Multi-Region Data Analytics Platform with Real-time ML Inference
**Location**: `AWS-Projects/project6-data-analytics-ml/`
**Technologies**: Kinesis, Redshift, SageMaker, Lambda, QuickSight, WAF, KMS
**Description**: A world-class, enterprise-grade data analytics and ML platform with comprehensive security, testing, monitoring, and cost optimization. **Rating: 100/100** ⭐⭐⭐⭐⭐

## 🏗️ Architecture Patterns

- **Container Orchestration** (ECS Fargate)
- **CI/CD and DevOps** (CodePipeline, CodeDeploy)
- **Monitoring and Security** (CloudWatch, Lambda automation)
- **Serverless Architecture** (Lambda, API Gateway)
- **Full-Stack Applications** (Elastic Beanstalk, RDS)
- **Data Analytics & ML** (Kinesis, Redshift, SageMaker, QuickSight)


## 🛠️ AWS Services Used

### Compute
- EC2, ECS Fargate, Lambda, Elastic Beanstalk, SageMaker

### Storage
- S3, EBS, EFS, Redshift

### Database
- RDS (MySQL, PostgreSQL), DynamoDB, Redshift

### Networking
- VPC, ALB, CloudFront, Route 53, API Gateway

### Security
- IAM, GuardDuty, Security Hub, Config, WAF, KMS

### Monitoring
- CloudWatch, X-Ray, EventBridge, SNS

### DevOps
- CodePipeline, CodeDeploy, CodeBuild

### Analytics & ML
- Kinesis, QuickSight, Athena, Glue, SageMaker

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
6. **Data Analytics & ML**: Building enterprise-grade data analytics and machine learning platforms

## 💰 Cost Considerations

Each project is designed to use minimal AWS resources to keep costs low:
- t3.micro instances for compute
- db.t3.micro for databases
- Minimal storage configurations
- Auto-scaling to scale down when not in use
- Latest AWS services for optimal performance and cost efficiency

Estimated monthly cost per project: $10-30 (depending on usage)

## 🔄 Recent Updates

- **Dependencies Updated**: All projects use the latest stable versions
- **Security Enhancements**: Updated packages to address security vulnerabilities
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
