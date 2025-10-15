# Troubleshooting Guide - Data Analytics ML Platform

## Common Issues and Solutions

### 1. Kinesis Stream Issues

#### Issue: Kinesis Stream Throttling
**Symptoms:**
- `WriteProvisionedThroughputExceeded` errors
- High latency in data processing
- Lambda function timeouts

**Solutions:**
```bash
# Check current shard count
aws kinesis describe-stream --stream-name data-analytics-ml-analytics-data-stream

# Increase shard count
aws kinesis update-shard-count \
    --stream-name data-analytics-ml-analytics-data-stream \
    --target-shard-count 4 \
    --scaling-type UNIFORM_SCALING
```

#### Issue: Kinesis Records Not Being Processed
**Symptoms:**
- No Lambda invocations
- Records accumulating in stream
- No data in Redshift

**Solutions:**
1. Check Lambda function status:
```bash
aws lambda get-function --function-name data-analytics-ml-analytics-data-processor
```

2. Check event source mapping:
```bash
aws lambda list-event-source-mappings --function-name data-analytics-ml-analytics-data-processor
```

3. Verify IAM permissions:
```bash
aws iam get-role-policy --role-name data-analytics-ml-analytics-lambda-execution-role --policy-name data-analytics-ml-analytics-lambda-kinesis-policy
```

### 2. Redshift Cluster Issues

#### Issue: Redshift Cluster Not Available
**Symptoms:**
- Connection timeouts
- Lambda function errors
- No data in tables

**Solutions:**
1. Check cluster status:
```bash
aws redshift describe-clusters --cluster-identifier data-analytics-ml-analytics-cluster
```

2. Check security groups:
```bash
aws redshift describe-clusters --cluster-identifier data-analytics-ml-analytics-cluster --query "Clusters[0].VpcSecurityGroups"
```

3. Verify VPC configuration:
```bash
aws redshift describe-clusters --cluster-identifier data-analytics-ml-analytics-cluster --query "Clusters[0].VpcId"
```

#### Issue: Redshift Query Performance
**Symptoms:**
- Slow query execution
- High CPU utilization
- Query timeouts

**Solutions:**
1. Check query performance:
```sql
SELECT query, starttime, endtime, duration, rows
FROM stl_query
WHERE starttime > CURRENT_DATE - INTERVAL '1 day'
ORDER BY duration DESC
LIMIT 10;
```

2. Analyze table statistics:
```sql
ANALYZE events;
ANALYZE ml_predictions;
```

3. Check for table bloat:
```sql
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables
ORDER BY n_tup_ins DESC;
```

### 3. SageMaker Endpoint Issues

#### Issue: SageMaker Endpoint Not Responding
**Symptoms:**
- 5XX errors from endpoint
- High latency
- Lambda function timeouts

**Solutions:**
1. Check endpoint status:
```bash
aws sagemaker describe-endpoint --endpoint-name data-analytics-ml-analytics-endpoint
```

2. Check endpoint configuration:
```bash
aws sagemaker describe-endpoint-config --endpoint-config-name data-analytics-ml-analytics-endpoint-config
```

3. Check model status:
```bash
aws sagemaker describe-model --model-name data-analytics-ml-analytics-model
```

#### Issue: Model Prediction Errors
**Symptoms:**
- Invalid input errors
- Prediction failures
- Inconsistent results

**Solutions:**
1. Validate input format:
```python
# Check feature count and types
features = [0.35, 0.5, 0.5, 1, 0, 0.05, 0.5, 0.2]
assert len(features) == 8, f"Expected 8 features, got {len(features)}"
assert all(isinstance(f, (int, float)) for f in features), "All features must be numeric"
```

2. Test endpoint directly:
```bash
aws sagemaker-runtime invoke-endpoint \
    --endpoint-name data-analytics-ml-analytics-endpoint \
    --content-type application/json \
    --body '{"instances": [[0.35, 0.5, 0.5, 1, 0, 0.05, 0.5, 0.2]]}' \
    response.json
```

### 4. Lambda Function Issues

#### Issue: Lambda Function Timeouts
**Symptoms:**
- Function timeouts
- Incomplete processing
- Error logs

**Solutions:**
1. Increase timeout:
```bash
aws lambda update-function-configuration \
    --function-name data-analytics-ml-analytics-data-processor \
    --timeout 300
```

2. Increase memory:
```bash
aws lambda update-function-configuration \
    --function-name data-analytics-ml-analytics-data-processor \
    --memory-size 512
```

3. Check function logs:
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/data-analytics-ml-analytics
```

#### Issue: Lambda Function Errors
**Symptoms:**
- Function failures
- Error logs
- No data processing

**Solutions:**
1. Check function logs:
```bash
aws logs filter-log-events \
    --log-group-name /aws/lambda/data-analytics-ml-analytics-data-processor \
    --start-time $(date -d '1 hour ago' +%s)000
```

2. Test function locally:
```python
import json
from lambda_functions.data_processor import lambda_handler

# Test event
test_event = {
    "Records": [
        {
            "kinesis": {
                "data": "eyJ0aW1lc3RhbXAiOiIyMDI0LTAxLTE1VDEwOjAwOjAwWiIsInVzZXJfaWQiOiJ1c2VyXzAwMDAwMSIsImV2ZW50X3R5cGUiOiJ2aWV3In0=",
                "sequenceNumber": "1234567890"
            }
        }
    ]
}

result = lambda_handler(test_event, None)
print(result)
```

### 5. S3 Data Lake Issues

#### Issue: S3 Access Denied
**Symptoms:**
- Access denied errors
- Lambda function failures
- No data in S3

**Solutions:**
1. Check bucket permissions:
```bash
aws s3api get-bucket-policy --bucket data-analytics-ml-analytics-data-lake-12345678
```

2. Check IAM permissions:
```bash
aws iam get-role-policy --role-name data-analytics-ml-analytics-lambda-execution-role --policy-name data-analytics-ml-analytics-lambda-kinesis-policy
```

3. Test S3 access:
```bash
aws s3 ls s3://data-analytics-ml-analytics-data-lake-12345678/
```

#### Issue: S3 Data Not Partitioned
**Symptoms:**
- Poor query performance
- High costs
- Slow data access

**Solutions:**
1. Check data structure:
```bash
aws s3 ls s3://data-analytics-ml-analytics-data-lake-12345678/events/ --recursive
```

2. Verify partitioning:
```bash
aws s3 ls s3://data-analytics-ml-analytics-data-lake-12345678/events/year=2024/month=01/day=15/
```

### 6. CloudWatch Monitoring Issues

#### Issue: No Metrics Available
**Symptoms:**
- Empty dashboards
- No alarms
- Missing data

**Solutions:**
1. Check metric namespaces:
```bash
aws cloudwatch list-metrics --namespace AWS/Kinesis
aws cloudwatch list-metrics --namespace AWS/Redshift
aws cloudwatch list-metrics --namespace AWS/SageMaker
```

2. Verify metric filters:
```bash
aws logs describe-metric-filters --log-group-name /aws/lambda/data-analytics-ml-analytics-data-processor
```

3. Check alarm status:
```bash
aws cloudwatch describe-alarms --alarm-names data-analytics-ml-analytics-kinesis-throttle
```

### 7. Data Quality Issues

#### Issue: Data Quality Check Failures
**Symptoms:**
- Quality check failures
- Alert notifications
- Data inconsistencies

**Solutions:**
1. Check data quality logs:
```bash
aws logs filter-log-events \
    --log-group-name /aws/lambda/data-analytics-ml-analytics-data-quality-checker \
    --start-time $(date -d '1 hour ago' +%s)000
```

2. Verify data completeness:
```sql
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN user_id IS NULL THEN 1 END) as null_user_ids,
    COUNT(CASE WHEN event_type IS NULL THEN 1 END) as null_event_types
FROM events 
WHERE processed_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour';
```

3. Check data freshness:
```sql
SELECT MAX(processed_at) as latest_processed
FROM events;
```

### 8. Network and Security Issues

#### Issue: VPC Connectivity Problems
**Symptoms:**
- Connection timeouts
- Network errors
- Service unavailability

**Solutions:**
1. Check VPC configuration:
```bash
aws ec2 describe-vpcs --vpc-ids vpc-12345678
```

2. Verify security groups:
```bash
aws ec2 describe-security-groups --group-ids sg-12345678
```

3. Check route tables:
```bash
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-12345678"
```

#### Issue: IAM Permission Errors
**Symptoms:**
- Access denied errors
- Service failures
- Authentication issues

**Solutions:**
1. Check IAM policies:
```bash
aws iam list-attached-role-policies --role-name data-analytics-ml-analytics-lambda-execution-role
```

2. Verify policy documents:
```bash
aws iam get-role-policy --role-name data-analytics-ml-analytics-lambda-execution-role --policy-name data-analytics-ml-analytics-lambda-kinesis-policy
```

3. Test permissions:
```bash
aws sts get-caller-identity
```

## Diagnostic Commands

### System Health Check
```bash
# Run comprehensive health check
./scripts/monitor.sh dashboard

# Check specific components
./scripts/monitor.sh kinesis
./scripts/monitor.sh redshift
./scripts/monitor.sh sagemaker
./scripts/monitor.sh lambda
```

### Log Analysis
```bash
# Check Lambda logs
aws logs filter-log-events \
    --log-group-name /aws/lambda/data-analytics-ml-analytics-data-processor \
    --start-time $(date -d '1 hour ago' +%s)000 \
    --filter-pattern "ERROR"

# Check CloudWatch alarms
aws cloudwatch describe-alarms --state-value ALARM
```

### Performance Analysis
```bash
# Check Kinesis metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/Kinesis \
    --metric-name IncomingRecords \
    --dimensions Name=StreamName,Value=data-analytics-ml-analytics-data-stream \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum

# Check Redshift performance
aws cloudwatch get-metric-statistics \
    --namespace AWS/Redshift \
    --metric-name CPUUtilization \
    --dimensions Name=ClusterIdentifier,Value=data-analytics-ml-analytics-cluster \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average
```

## Emergency Procedures

### 1. Service Recovery
```bash
# Restart Lambda function
aws lambda update-function-configuration \
    --function-name data-analytics-ml-analytics-data-processor \
    --timeout 300

# Restart SageMaker endpoint
aws sagemaker update-endpoint \
    --endpoint-name data-analytics-ml-analytics-endpoint \
    --endpoint-config-name data-analytics-ml-analytics-endpoint-config
```

### 2. Data Recovery
```bash
# Restore from S3 backup
aws s3 sync s3://backup-bucket/events/ s3://data-analytics-ml-analytics-data-lake-12345678/events/

# Restore Redshift from snapshot
aws redshift restore-from-cluster-snapshot \
    --cluster-identifier data-analytics-ml-analytics-cluster-restored \
    --snapshot-identifier data-analytics-ml-analytics-cluster-snapshot
```

### 3. Rollback Procedures
```bash
# Rollback to previous Terraform state
cd infrastructure
terraform plan -var-file="terraform.tfvars.backup"
terraform apply -var-file="terraform.tfvars.backup"

# Rollback Lambda function
aws lambda update-function-code \
    --function-name data-analytics-ml-analytics-data-processor \
    --s3-bucket backup-bucket \
    --s3-key lambda-backup.zip
```

## Prevention and Best Practices

### 1. Monitoring Setup
- Set up comprehensive CloudWatch alarms
- Configure SNS notifications for critical alerts
- Implement automated health checks
- Monitor cost and usage patterns

### 2. Data Quality
- Implement data validation at ingestion
- Set up automated data quality checks
- Monitor data freshness and completeness
- Implement data lineage tracking

### 3. Security
- Regular security audits
- Implement least privilege access
- Monitor for unusual access patterns
- Keep security groups and policies updated

### 4. Performance
- Regular performance testing
- Monitor resource utilization
- Implement auto-scaling where appropriate
- Optimize queries and data processing

### 5. Backup and Recovery
- Regular automated backups
- Test recovery procedures
- Implement cross-region replication
- Document recovery procedures

## Support and Escalation

### 1. Internal Support
- Check internal documentation
- Review system logs and metrics
- Consult with team members
- Use diagnostic tools and scripts

### 2. AWS Support
- Create AWS support case for critical issues
- Provide detailed error logs and metrics
- Include system configuration details
- Follow AWS support guidelines

### 3. Emergency Contacts
- System administrators
- AWS support team
- Data engineering team
- Business stakeholders

## Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Data Analytics Services Documentation](https://docs.aws.amazon.com/data-analytics/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CloudWatch Monitoring Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-resources/)
