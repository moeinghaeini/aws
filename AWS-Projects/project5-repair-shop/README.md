# Project 5: Repair Shop Application Deployment on AWS

## Overview
This project demonstrates deploying a complete repair shop management application on AWS using Elastic Beanstalk for the backend, AWS Amplify for the frontend, and RDS for the database. The application includes customer management, repair tracking, and inventory management features.

## Architecture
- **Frontend**: React application deployed on AWS Amplify
- **Backend**: Node.js/Express API deployed on Elastic Beanstalk
- **Database**: PostgreSQL on RDS
- **Authentication**: AWS Cognito
- **File Storage**: S3 for document storage
- **CDN**: CloudFront for content delivery
- **Monitoring**: CloudWatch for logging and monitoring

## Components
1. **Repair Shop Frontend** (React with Material-UI)
2. **Backend API** (Node.js/Express with Sequelize ORM)
3. **Database Schema** (PostgreSQL with migrations)
4. **Authentication System** (AWS Cognito)
5. **File Upload System** (S3 integration)
6. **Deployment Configuration** (Elastic Beanstalk, Amplify)

## Features
- **Customer Management**: Add, edit, and view customer information
- **Repair Tracking**: Track repair status and progress
- **Inventory Management**: Manage parts and supplies
- **Document Management**: Upload and store repair documents
- **User Authentication**: Secure login and user management
- **Reporting**: Generate repair reports and analytics
- **Mobile Responsive**: Works on desktop and mobile devices

## Deployment Components
- **Elastic Beanstalk**: Backend API deployment
- **AWS Amplify**: Frontend hosting and CI/CD
- **RDS PostgreSQL**: Database hosting
- **S3**: File storage and static assets
- **CloudFront**: CDN for global content delivery
- **Route 53**: DNS management
- **Cognito**: User authentication and authorization
