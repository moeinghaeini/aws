# Project 6: Multi-Region Data Analytics Platform with Real-time ML Inference

## Overview
This project demonstrates a comprehensive data analytics and machine learning platform built entirely with Infrastructure as Code (IaC) using Terraform. The platform processes real-time streaming data, performs analytics, and provides ML inference capabilities across multiple AWS regions.

## Architecture

### Core Components
- **Data Ingestion**: Amazon Kinesis Data Streams for real-time data processing
- **Data Storage**: Amazon S3 for data lake, Amazon Redshift for data warehouse
- **Data Processing**: AWS Lambda functions for stream processing and ML inference
- **Machine Learning**: Amazon SageMaker for model deployment and inference
- **Analytics**: Amazon QuickSight for business intelligence dashboards
- **Data Catalog**: AWS Glue for metadata management
- **Query Engine**: Amazon Athena for ad-hoc analytics
- **Monitoring**: Amazon CloudWatch for observability and alerting

### Architecture Diagram
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Data Sources  │───▶│  Kinesis Stream  │───▶│  Lambda Processor│
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   QuickSight    │◀───│   Redshift       │◀───│   S3 Data Lake  │
│   Dashboard     │    │   Data Warehouse │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Gateway   │───▶│  ML Inference    │───▶│   SageMaker     │
│                 │    │  Lambda          │    │   Endpoint      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Features

### Real-time Data Processing
- **Stream Processing**: Kinesis Data Streams with 2 shards for high throughput
- **Data Validation**: Comprehensive data quality checks and validation
- **Data Enrichment**: Real-time feature engineering and data augmentation
- **Error Handling**: Robust error handling with dead letter queues

### Machine Learning Capabilities
- **Real-time Inference**: SageMaker endpoint for low-latency predictions
- **Feature Engineering**: Automated feature extraction and normalization
- **Model Monitoring**: CloudWatch metrics for model performance tracking
- **A/B Testing**: Support for model versioning and experimentation

### Analytics and Reporting
- **Data Warehouse**: Redshift cluster for analytical queries
- **Business Intelligence**: QuickSight dashboards for stakeholders
- **Ad-hoc Analytics**: Athena for SQL-based data exploration
- **Data Catalog**: Glue for metadata management and discovery

### Monitoring and Observability
- **Real-time Monitoring**: CloudWatch dashboards and alarms
- **Data Quality**: Automated data quality checks and alerting
- **Performance Metrics**: End-to-end latency and throughput monitoring
- **Cost Optimization**: Budget alerts and resource optimization

### Security and Compliance
- **Encryption**: End-to-end encryption using AWS KMS
- **Access Control**: IAM roles and policies with least privilege
- **Network Security**: VPC with private subnets and security groups
- **Audit Logging**: CloudTrail for comprehensive audit trails

## Infrastructure Components

### Networking
- **VPC**: Custom VPC with public, private, and database subnets
- **NAT Gateway**: For outbound internet access from private subnets
- **VPC Endpoints**: For secure access to AWS services
- **Security Groups**: Network-level security controls

### Compute
- **Lambda Functions**: Serverless compute for data processing
- **SageMaker**: Managed ML platform for model deployment
- **Redshift**: Managed data warehouse for analytics

### Storage
- **S3 Data Lake**: Scalable object storage with lifecycle policies
- **Redshift**: Columnar storage for analytical workloads
- **Glue Data Catalog**: Centralized metadata repository

### Analytics
- **Kinesis Analytics**: Real-time stream processing
- **Athena**: Serverless query service for S3 data
- **QuickSight**: Business intelligence and visualization

## Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.6 installed
- Python 3.11+ for Lambda functions
- jq for JSON processing in scripts

### Quick Start
1. **Clone and Navigate**:
   ```bash
   cd AWS-Projects/project6-data-analytics-ml
   ```

2. **Deploy Infrastructure**:
   ```bash
   ./scripts/deploy.sh
   ```

3. **Monitor Deployment**:
   ```bash
   ./scripts/monitor.sh
   ```

4. **Destroy Resources** (when done):
   ```bash
   ./scripts/destroy.sh
   ```

### Manual Deployment
1. **Initialize Terraform**:
   ```bash
   cd infrastructure
   terraform init
   ```

2. **Plan Deployment**:
   ```bash
   terraform plan
   ```

3. **Apply Changes**:
   ```bash
   terraform apply
   ```

## Configuration

### Environment Variables
- `AWS_REGION`: Primary AWS region (default: us-east-1)
- `SECONDARY_REGION`: Secondary region for DR (default: us-west-2)
- `ENVIRONMENT`: Environment name (default: analytics)
- `PROJECT_NAME`: Project identifier (default: data-analytics-ml)

### Customizable Parameters
- Kinesis shard count
- Redshift node type and cluster size
- SageMaker instance type
- Lambda timeout and memory
- Monitoring and alerting thresholds

## Data Flow

### 1. Data Ingestion
- Data sources send events to Kinesis Data Streams
- Streams are partitioned by user_id for scalability
- Data is encrypted in transit and at rest

### 2. Real-time Processing
- Lambda function processes Kinesis records
- Data validation and enrichment
- Feature engineering for ML models
- Storage in S3 data lake and Redshift

### 3. ML Inference
- Real-time predictions via SageMaker endpoint
- Feature extraction and normalization
- Model scoring and confidence calculation
- Results stored for analytics

### 4. Analytics and Reporting
- Redshift for complex analytical queries
- QuickSight for business dashboards
- Athena for ad-hoc data exploration
- Glue for data catalog and discovery

## Monitoring and Alerting

### CloudWatch Dashboards
- **Kinesis Metrics**: Throughput, throttling, and error rates
- **Redshift Metrics**: CPU, storage, and query performance
- **SageMaker Metrics**: Model latency and error rates
- **Lambda Metrics**: Invocation count, duration, and errors

### Alarms and Notifications
- **Data Quality**: Automated data quality checks
- **Performance**: Latency and throughput thresholds
- **Errors**: 5XX errors and exception monitoring
- **Cost**: Budget alerts and spending thresholds

### Data Quality Monitoring
- **Completeness**: Missing value detection
- **Consistency**: Duplicate record identification
- **Freshness**: Data processing latency monitoring
- **Anomaly Detection**: Unusual pattern identification

## Cost Optimization

### Resource Sizing
- **Right-sized Instances**: Optimized for workload requirements
- **Auto-scaling**: Dynamic scaling based on demand
- **Lifecycle Policies**: Automated data archival and deletion
- **Reserved Capacity**: Cost-effective for predictable workloads

### Monitoring and Alerts
- **Budget Alerts**: Monthly spending notifications
- **Resource Utilization**: Underutilized resource identification
- **Cost Allocation**: Tag-based cost tracking
- **Optimization Recommendations**: AWS Cost Explorer insights

## Security Best Practices

### Data Protection
- **Encryption**: KMS encryption for all data at rest
- **Access Control**: IAM roles with least privilege
- **Network Security**: VPC with private subnets
- **Audit Logging**: CloudTrail for all API calls

### Compliance
- **Data Retention**: Configurable retention policies
- **Backup and Recovery**: Automated backup strategies
- **Disaster Recovery**: Multi-region deployment
- **Security Monitoring**: GuardDuty and Security Hub

## Troubleshooting

### Common Issues
1. **Kinesis Throttling**: Increase shard count or optimize record size
2. **Lambda Timeouts**: Increase timeout or optimize code
3. **Redshift Performance**: Optimize queries or resize cluster
4. **SageMaker Latency**: Optimize model or increase instance size

### Debugging Tools
- **CloudWatch Logs**: Centralized logging for all services
- **X-Ray Tracing**: Distributed tracing for performance analysis
- **CloudWatch Insights**: Log analysis and querying
- **AWS CLI**: Command-line troubleshooting

### Health Checks
```bash
# Check overall system health
./scripts/monitor.sh dashboard

# Check specific components
./scripts/monitor.sh kinesis
./scripts/monitor.sh redshift
./scripts/monitor.sh sagemaker
./scripts/monitor.sh lambda
```

## Performance Optimization

### Kinesis Optimization
- **Shard Count**: Scale based on throughput requirements
- **Record Size**: Optimize for 1MB per record
- **Batch Processing**: Use batch operations for efficiency
- **Compression**: Enable compression for large payloads

### Redshift Optimization
- **Distribution Keys**: Optimize for query patterns
- **Sort Keys**: Improve query performance
- **Compression**: Automatic compression for storage efficiency
- **Workload Management**: Query prioritization and resource allocation

### Lambda Optimization
- **Memory Allocation**: Right-size for workload requirements
- **Concurrency**: Optimize for throughput and cost
- **Cold Start**: Minimize with provisioned concurrency
- **Dependencies**: Optimize package size and imports

## Scaling Considerations

### Horizontal Scaling
- **Kinesis Shards**: Add shards for increased throughput
- **Lambda Concurrency**: Scale based on demand
- **Redshift Nodes**: Add nodes for increased capacity
- **SageMaker Instances**: Scale endpoint capacity

### Vertical Scaling
- **Instance Types**: Upgrade to larger instances
- **Memory Allocation**: Increase Lambda memory
- **Storage**: Increase Redshift storage capacity
- **Network**: Optimize network performance

## Disaster Recovery

### Multi-Region Setup
- **Primary Region**: us-east-1 for active workloads
- **Secondary Region**: us-west-2 for disaster recovery
- **Cross-Region Replication**: Automated data replication
- **Failover Procedures**: Automated failover mechanisms

### Backup Strategies
- **S3 Cross-Region Replication**: Automated backup
- **Redshift Snapshots**: Point-in-time recovery
- **Lambda Code**: Version control and deployment
- **Configuration**: Infrastructure as Code backup

## Cost Estimation

### Monthly Costs (Approximate)
- **Kinesis**: $50-100 (2 shards, 1M records/day)
- **Redshift**: $200-400 (dc2.large, single node)
- **SageMaker**: $100-200 (ml.t2.medium endpoint)
- **Lambda**: $20-50 (1M invocations/month)
- **S3**: $10-30 (100GB storage)
- **CloudWatch**: $20-40 (logs and metrics)
- **Total**: $400-820/month

### Cost Optimization Tips
- Use spot instances for SageMaker training
- Implement S3 lifecycle policies
- Monitor and optimize Lambda memory
- Use Redshift pause/resume for non-production
- Implement cost allocation tags

## Support and Maintenance

### Regular Maintenance
- **Security Updates**: Regular security patch updates
- **Performance Tuning**: Ongoing performance optimization
- **Cost Review**: Monthly cost analysis and optimization
- **Backup Verification**: Regular backup testing

### Monitoring and Alerting
- **24/7 Monitoring**: CloudWatch alarms and notifications
- **Performance Metrics**: Regular performance analysis
- **Error Tracking**: Automated error detection and alerting
- **Capacity Planning**: Proactive capacity management

## Contributing

### Development Guidelines
- Follow Terraform best practices
- Use consistent naming conventions
- Document all changes
- Test in development environment first

### Code Review Process
- All changes require review
- Test deployment in staging
- Update documentation
- Monitor production impact

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- AWS Well-Architected Framework
- Terraform best practices
- AWS Data Analytics services documentation
- Community contributions and feedback
