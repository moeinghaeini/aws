# Project 1: Containerized LMS Migration and Troubleshooting

## Overview
This project demonstrates containerizing a Learning Management System (LMS) frontend and deploying it on AWS ECS Fargate with Application Load Balancer (ALB). The project includes common troubleshooting scenarios and solutions.

## Architecture
- **Frontend**: React-based LMS application
- **Container**: Docker containerized application
- **Orchestration**: AWS ECS Fargate
- **Load Balancer**: Application Load Balancer (ALB)
- **Networking**: VPC with public/private subnets
- **Security**: Security Groups and IAM roles

## Components
1. LMS Frontend Application (React)
2. Dockerfile for containerization
3. ECS Task Definition
4. ECS Service Configuration
5. Application Load Balancer setup
6. VPC and networking configuration
7. Security Groups
8. Troubleshooting scenarios and solutions

## Deployment Steps
1. Build and push Docker image to ECR
2. Create ECS cluster
3. Deploy ECS service with task definition
4. Configure ALB
5. Test and troubleshoot common issues

## Common Issues Covered
- ECS container startup failures
- ALB health check failures
- Security group misconfigurations
- Network connectivity issues
- IAM permission problems
