# LMS ECS Troubleshooting Guide

## Common Issues and Solutions

### 1. ECS Container Startup Failures

#### Symptoms:
- Tasks stuck in PENDING state
- Tasks failing to start
- Container exit codes other than 0

#### Troubleshooting Steps:

1. **Check ECS Service Events:**
```bash
aws ecs describe-services --cluster lms-cluster --services lms-service
```

2. **Check Task Definition:**
```bash
aws ecs describe-task-definition --task-definition lms-frontend
```

3. **Check CloudWatch Logs:**
```bash
aws logs describe-log-streams --log-group-name /ecs/lms-frontend
aws logs get-log-events --log-group-name /ecs/lms-frontend --log-stream-name <stream-name>
```

#### Common Causes:
- **Insufficient CPU/Memory:** Increase task definition resources
- **Wrong Image URI:** Verify ECR repository URL
- **Missing IAM Permissions:** Check task execution role
- **Health Check Failures:** Verify health check endpoint

### 2. ALB Health Check Failures

#### Symptoms:
- ALB targets showing as unhealthy
- 502/503 errors from ALB
- Application not accessible

#### Troubleshooting Steps:

1. **Check Target Group Health:**
```bash
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

2. **Verify Security Groups:**
```bash
aws ec2 describe-security-groups --group-ids <security-group-id>
```

3. **Check ALB Access Logs:**
```bash
aws s3 ls s3://<alb-access-logs-bucket>/
```

#### Common Causes:
- **Security Group Misconfiguration:** ALB can't reach ECS tasks
- **Wrong Health Check Path:** Verify `/health` endpoint
- **Port Mismatch:** Ensure container port matches target group port
- **Network ACLs:** Check VPC network ACLs

### 3. Security Group Configuration Issues

#### Symptoms:
- Connection timeouts
- ALB can't reach ECS tasks
- External traffic can't reach ALB

#### Troubleshooting Steps:

1. **ALB Security Group:**
```bash
# Should allow inbound 80/443 from 0.0.0.0/0
# Should allow outbound to ECS security group on port 80
```

2. **ECS Security Group:**
```bash
# Should allow inbound 80 from ALB security group
# Should allow outbound to 0.0.0.0/0
```

3. **Test Connectivity:**
```bash
# From ALB subnet, test ECS task connectivity
aws ec2 describe-instances --filters "Name=tag:Name,Values=*"
```

### 4. IAM Permission Issues

#### Symptoms:
- ECS tasks fail to start
- Can't pull images from ECR
- CloudWatch logs not appearing

#### Troubleshooting Steps:

1. **Check Task Execution Role:**
```bash
aws iam get-role --role-name lms-ecs-task-execution-role
aws iam list-attached-role-policies --role-name lms-ecs-task-execution-role
```

2. **Required Policies:**
- `AmazonECSTaskExecutionRolePolicy`
- ECR read permissions
- CloudWatch logs permissions

### 5. Network Connectivity Issues

#### Symptoms:
- Tasks can't reach external services
- DNS resolution failures
- Timeout errors

#### Troubleshooting Steps:

1. **Check VPC Configuration:**
```bash
aws ec2 describe-vpcs --vpc-ids <vpc-id>
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
```

2. **Check Route Tables:**
```bash
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"
```

3. **Check NAT Gateway (if using private subnets):**
```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>"
```

## Monitoring and Logging

### CloudWatch Metrics to Monitor:
- ECS Service CPU/Memory utilization
- ALB target response time
- ALB HTTP error rates
- ECS task count

### Useful Commands:

```bash
# Get ECS service status
aws ecs describe-services --cluster lms-cluster --services lms-service

# Get running tasks
aws ecs list-tasks --cluster lms-cluster --service-name lms-service

# Get task details
aws ecs describe-tasks --cluster lms-cluster --tasks <task-arn>

# Get ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Get recent logs
aws logs filter-log-events --log-group-name /ecs/lms-frontend --start-time $(date -d '1 hour ago' +%s)000
```

## Performance Optimization

### ECS Task Configuration:
- Use appropriate CPU/Memory allocation
- Enable container insights
- Set up auto-scaling

### ALB Configuration:
- Enable access logs
- Configure appropriate health check intervals
- Use sticky sessions if needed

### Monitoring Setup:
- Set up CloudWatch alarms
- Configure SNS notifications
- Use AWS X-Ray for tracing
