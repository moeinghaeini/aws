# Project 2: CI/CD Pipeline for GlobalMart E-Commerce Platform

## Overview
This project implements a complete CI/CD pipeline for the GlobalMart e-commerce platform using AWS CodePipeline, CodeDeploy, and EC2. The pipeline automates the build, test, and deployment process for a web application.

## Architecture
- **Source Control**: GitHub repository
- **Build**: AWS CodeBuild
- **Deploy**: AWS CodeDeploy
- **Pipeline**: AWS CodePipeline
- **Infrastructure**: EC2 instances with Auto Scaling
- **Load Balancer**: Application Load Balancer
- **Database**: RDS MySQL
- **Monitoring**: CloudWatch

## Components
1. **E-Commerce Web Application** (Node.js/Express)
2. **Infrastructure as Code** (Terraform)
3. **CI/CD Pipeline Configuration**
4. **EC2 Instance Configuration**
5. **Auto Scaling Group Setup**
6. **Database Configuration**
7. **Monitoring and Logging**

## Pipeline Stages
1. **Source**: GitHub repository webhook
2. **Build**: CodeBuild with npm install and test
3. **Deploy**: CodeDeploy to EC2 instances
4. **Post-Deploy**: Health checks and notifications

## Features
- Automated testing
- Blue/Green deployments
- Auto-scaling based on demand
- Health monitoring
- Rollback capabilities
- Security scanning
