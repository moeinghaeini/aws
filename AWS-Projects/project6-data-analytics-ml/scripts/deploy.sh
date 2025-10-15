#!/bin/bash

# Project 6: Data Analytics ML Platform Deployment Script
# This script deploys the complete data analytics and ML platform on AWS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="data-analytics-ml"
ENVIRONMENT="analytics"
AWS_REGION="us-east-1"
SECONDARY_REGION="us-west-2"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "All prerequisites met!"
}

# Function to create S3 bucket for Terraform state
create_terraform_state_bucket() {
    print_status "Creating S3 bucket for Terraform state..."
    
    BUCKET_NAME="${PROJECT_NAME}-terraform-state-$(date +%s)"
    
    aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION}
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket ${BUCKET_NAME} \
        --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    aws s3api put-bucket-encryption \
        --bucket ${BUCKET_NAME} \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    print_success "Terraform state bucket created: ${BUCKET_NAME}"
    echo "BUCKET_NAME=${BUCKET_NAME}" > .env
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd infrastructure
    
    # Create terraform.tfvars file
    cat > terraform.tfvars << EOF
aws_region = "${AWS_REGION}"
secondary_region = "${SECONDARY_REGION}"
environment = "${ENVIRONMENT}"
project_name = "${PROJECT_NAME}"
redshift_password = "AnalyticsPassword123!"
alert_email = "admin@example.com"
kinesis_shard_count = 2
redshift_node_type = "dc2.large"
sagemaker_instance_type = "ml.t2.medium"
lambda_timeout = 300
enable_xray_tracing = true
log_retention_days = 14
backup_retention_days = 7
enable_encryption = true
enable_monitoring = true
enable_auto_scaling = true
data_retention_days = 90
ml_model_version = "1.0"
cost_budget_limit = 1000
EOF
    
    # Initialize Terraform
    terraform init
    
    print_success "Terraform initialized!"
}

# Function to plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment..."
    
    cd infrastructure
    
    terraform plan -out=tfplan
    
    print_success "Terraform plan completed!"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure..."
    
    cd infrastructure
    
    # Apply Terraform plan
    terraform apply tfplan
    
    print_success "Infrastructure deployed successfully!"
}

# Function to create Redshift tables
create_redshift_tables() {
    print_status "Creating Redshift tables..."
    
    # Get Redshift cluster endpoint
    REDSHIFT_ENDPOINT=$(terraform output -raw redshift_cluster_endpoint)
    
    # Create tables using AWS CLI
    aws redshift-data execute-statement \
        --cluster-identifier ${PROJECT_NAME}-${ENVIRONMENT}-cluster \
        --database analytics \
        --sql "CREATE TABLE IF NOT EXISTS events (
            id BIGINT IDENTITY(1,1),
            timestamp TIMESTAMP,
            user_id VARCHAR(64),
            event_type VARCHAR(32),
            value DOUBLE PRECISION,
            session_duration INTEGER,
            user_segment VARCHAR(32),
            ml_prediction VARCHAR(MAX),
            processed_at TIMESTAMP
        );"
    
    aws redshift-data execute-statement \
        --cluster-identifier ${PROJECT_NAME}-${ENVIRONMENT}-cluster \
        --database analytics \
        --sql "CREATE TABLE IF NOT EXISTS ml_predictions (
            id BIGINT IDENTITY(1,1),
            user_id VARCHAR(64),
            prediction DOUBLE PRECISION,
            confidence DOUBLE PRECISION,
            probability DOUBLE PRECISION,
            features VARCHAR(MAX),
            request_timestamp TIMESTAMP,
            response_timestamp TIMESTAMP
        );"
    
    print_success "Redshift tables created!"
}

# Function to deploy ML model
deploy_ml_model() {
    print_status "Deploying ML model..."
    
    # Create a simple ML model for demonstration
    python3 -c "
import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import make_classification

# Generate sample data
X, y = make_classification(n_samples=1000, n_features=8, n_classes=2, random_state=42)

# Train model
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X, y)

# Save model
joblib.dump(model, 'model.pkl')
print('Model trained and saved!')
"
    
    # Upload model to S3
    aws s3 cp model.pkl s3://${PROJECT_NAME}-${ENVIRONMENT}-ml-artifacts/model/model.tar.gz
    
    print_success "ML model deployed!"
}

# Function to test the deployment
test_deployment() {
    print_status "Testing deployment..."
    
    # Test Kinesis stream
    aws kinesis describe-stream --stream-name ${PROJECT_NAME}-${ENVIRONMENT}-data-stream
    
    # Test Lambda functions
    aws lambda list-functions --query "Functions[?contains(FunctionName, '${PROJECT_NAME}')]"
    
    # Test SageMaker endpoint
    aws sagemaker describe-endpoint --endpoint-name ${PROJECT_NAME}-${ENVIRONMENT}-endpoint
    
    print_success "Deployment test completed!"
}

# Function to display deployment information
display_deployment_info() {
    print_status "Deployment Information:"
    
    cd infrastructure
    
    echo ""
    echo "=== DEPLOYMENT SUMMARY ==="
    echo "Project: ${PROJECT_NAME}"
    echo "Environment: ${ENVIRONMENT}"
    echo "Region: ${AWS_REGION}"
    echo "Secondary Region: ${SECONDARY_REGION}"
    echo ""
    
    echo "=== RESOURCE ENDPOINTS ==="
    echo "Kinesis Stream: $(terraform output -raw kinesis_stream_arn)"
    echo "Redshift Cluster: $(terraform output -raw redshift_cluster_endpoint)"
    echo "SageMaker Endpoint: $(terraform output -raw sagemaker_endpoint_name)"
    echo "QuickSight Dashboard: $(terraform output -raw quicksight_dashboard_url)"
    echo ""
    
    echo "=== NEXT STEPS ==="
    echo "1. Configure your data sources to send data to the Kinesis stream"
    echo "2. Access the QuickSight dashboard for analytics"
    echo "3. Monitor the CloudWatch dashboards for system health"
    echo "4. Set up data quality monitoring alerts"
    echo ""
    
    print_success "Deployment completed successfully!"
}

# Main deployment function
main() {
    echo "=========================================="
    echo "  Data Analytics ML Platform Deployment"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    create_terraform_state_bucket
    init_terraform
    plan_terraform
    
    # Ask for confirmation before applying
    echo ""
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_infrastructure
        create_redshift_tables
        deploy_ml_model
        test_deployment
        display_deployment_info
    else
        print_warning "Deployment cancelled by user."
        exit 0
    fi
}

# Run main function
main "$@"
