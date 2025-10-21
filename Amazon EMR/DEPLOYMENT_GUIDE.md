# Amazon EMR Big Data Platform - Deployment Guide

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** - Configured with appropriate permissions
2. **Terraform** - Version >= 1.0
3. **Python 3** - With pip package manager
4. **Git** - For version control

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Amazon\ EMR

# Install Python dependencies
pip install -r scripts/requirements.txt

# Make scripts executable
chmod +x scripts/*.sh
```

## 📋 Deployment Steps

### 1. Infrastructure Deployment

```bash
# Deploy the complete EMR infrastructure
./scripts/deploy.sh --action deploy --region us-east-1 --environment dev

# Or plan changes first
./scripts/deploy.sh --action plan --region us-east-1 --environment dev
```

### 2. Upload Scripts to S3

```bash
# Upload Spark scripts and bootstrap actions
./scripts/deploy.sh --action upload-scripts --region us-east-1
```

### 3. Generate Sample Data

The deployment script automatically generates sample data, but you can regenerate it:

```bash
# Generate sample sales and log data
python3 scripts/sample_data_generator.py \
    --bucket-name <your-data-bucket> \
    --data-type both \
    --num-records 1000 \
    --format csv
```

## 🔧 Running EMR Jobs

### Method 1: Console-based (AWS Console)
1. Navigate to EMR service in AWS Console
2. Select your cluster
3. Go to "Steps" tab
4. Click "Add step"
5. Configure your job and submit

### Method 2: CLI-based (This Script)
```bash
# Run Spark job
./scripts/run_emr_job.sh \
    --cluster-id j-1234567890 \
    --job-type spark \
    --script-path s3://your-bucket/scripts/spark_data_processor.py \
    --input-path s3://your-bucket/raw-data/sales/ \
    --output-path s3://your-bucket/processed-data/ \
    --monitor

# Run Python job
./scripts/run_emr_job.sh \
    --cluster-id j-1234567890 \
    --job-type python \
    --script-path s3://your-bucket/scripts/data_processor.py \
    --monitor
```

### Method 3: API-based (Programmatic)
```python
import boto3

# Initialize EMR client
emr_client = boto3.client('emr', region_name='us-east-1')

# Submit step
response = emr_client.add_job_flow_steps(
    JobFlowId='j-1234567890',
    Steps=[{
        'Name': 'Data Processing Job',
        'ActionOnFailure': 'CONTINUE',
        'HadoopJarStep': {
            'Jar': 'command-runner.jar',
            'Args': [
                'spark-submit',
                '--deploy-mode', 'cluster',
                's3://your-bucket/scripts/spark_data_processor.py'
            ]
        }
    }]
)

print(f"Step ID: {response['StepIds'][0]}")
```

## 📊 Monitoring and Management

### Access YARN Resource Manager
```bash
# Get cluster information
aws emr describe-cluster --cluster-id <cluster-id>

# Access YARN Resource Manager
# URL: http://<master-public-dns>:8088
```

### Access Spark History Server
```bash
# URL: http://<master-public-dns>:18080
```

### Access Hue Web Interface
```bash
# URL: http://<master-public-dns>:8888
```

### SSH to Master Node
```bash
# Use the private key from keys/ directory
ssh -i keys/emr_private_key.pem hadoop@<master-public-dns>
```

## 🔍 Troubleshooting

### Common Issues

1. **Cluster fails to start**
   - Check security groups allow necessary traffic
   - Verify IAM roles have correct permissions
   - Check subnet has internet access

2. **Steps fail to run**
   - Verify script exists in S3
   - Check script permissions and format
   - Review CloudWatch logs

3. **Auto-scaling not working**
   - Verify EMR managed scaling is enabled
   - Check scaling policy configuration
   - Monitor cluster metrics

### Logs and Debugging

```bash
# View cluster logs
aws logs describe-log-groups --log-group-name-prefix "/aws/emr"

# Get step details
aws emr describe-step --cluster-id <cluster-id> --step-id <step-id>

# List recent steps
aws emr list-steps --cluster-id <cluster-id>
```

## 🛠️ Configuration Options

### Environment Variables
```bash
export AWS_REGION="us-east-1"
export EMR_CLUSTER_ID="j-1234567890"
export S3_DATA_BUCKET="your-data-bucket"
export S3_SCRIPTS_BUCKET="your-scripts-bucket"
```

### Terraform Variables
```hcl
# infrastructure/terraform.tfvars
aws_region = "us-east-1"
environment = "dev"
emr_release_label = "emr-6.15.0"
master_instance_type = "m5.xlarge"
worker_instance_type = "m5.large"
worker_instance_count = 2
enable_auto_scaling = true
min_capacity = 1
max_capacity = 10
```

## 🔒 Security Best Practices

1. **Encryption**
   - S3 buckets use AES-256 encryption
   - EMR logs are encrypted in transit
   - SSH keys are generated securely

2. **Access Control**
   - IAM roles follow least privilege principle
   - Security groups restrict network access
   - VPC provides network isolation

3. **Monitoring**
   - CloudWatch logs for all activities
   - Step execution monitoring
   - Resource utilization tracking

## 💰 Cost Optimization

1. **Auto-scaling**
   - Configure appropriate min/max capacity
   - Use spot instances for worker nodes
   - Monitor and adjust scaling policies

2. **Resource Sizing**
   - Right-size instance types
   - Use appropriate storage types
   - Clean up unused resources

3. **Scheduling**
   - Run jobs during off-peak hours
   - Use transient clusters for batch jobs
   - Implement job scheduling

## 🧹 Cleanup

### Destroy Infrastructure
```bash
# Destroy all resources (with confirmation)
./scripts/deploy.sh --action destroy --region us-east-1 --environment dev --confirm
```

### Manual Cleanup
```bash
# Delete S3 buckets manually (if needed)
aws s3 rb s3://your-bucket --force

# Terminate EMR cluster
aws emr terminate-clusters --cluster-ids j-1234567890
```

## 📚 Additional Resources

- [AWS EMR Documentation](https://docs.aws.amazon.com/emr/)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [EMR Best Practices](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-best-practices.html)

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Consult AWS documentation
4. Contact the development team
