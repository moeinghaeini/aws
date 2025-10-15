# Project 4: Debugging a Broken Serverless Contact Form Workflow

## Overview
This project demonstrates debugging a broken serverless contact form workflow using AWS Lambda, API Gateway, S3, and DynamoDB. The project includes intentional issues that need to be identified and fixed, simulating real-world troubleshooting scenarios.

## Architecture
- **Frontend**: Static HTML form hosted on S3
- **API**: API Gateway with Lambda integration
- **Processing**: Lambda functions for form processing
- **Storage**: DynamoDB for contact submissions
- **Notifications**: SNS for email notifications
- **Monitoring**: CloudWatch for logging and debugging

## Components
1. **Contact Form Frontend** (HTML/CSS/JavaScript)
2. **API Gateway Configuration**
3. **Lambda Functions** (Form processing, validation, storage)
4. **DynamoDB Table** (Contact submissions)
5. **SNS Topic** (Email notifications)
6. **CloudWatch Logs** (Debugging and monitoring)

## Intended Issues to Debug
1. **CORS Configuration Problems**
2. **Lambda Function Errors**
3. **API Gateway Integration Issues**
4. **DynamoDB Permission Problems**
5. **SNS Notification Failures**
6. **Input Validation Issues**
7. **Error Handling Problems**

## Debugging Scenarios
- Form submission failures
- API timeout issues
- Database connection problems
- Email delivery failures
- CORS policy violations
- Lambda execution errors
- API Gateway configuration issues

## Tools and Techniques
- CloudWatch Logs analysis
- X-Ray tracing
- API Gateway logs
- Lambda function debugging
- DynamoDB query debugging
- SNS delivery status checking
