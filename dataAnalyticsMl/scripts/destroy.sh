#!/bin/bash

# Project 6: Data Analytics ML Platform Destruction Script
# This script destroys the complete data analytics and ML platform on AWS

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
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "All prerequisites met!"
}

# Function to backup important data
backup_data() {
    print_status "Backing up important data..."
    
    # Create backup directory
    BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p ${BACKUP_DIR}
    
    # Backup Terraform state
    if [ -f "infrastructure/terraform.tfstate" ]; then
        cp infrastructure/terraform.tfstate ${BACKUP_DIR}/
        print_success "Terraform state backed up to ${BACKUP_DIR}/"
    fi
    
    # Backup configuration files
    if [ -f "infrastructure/terraform.tfvars" ]; then
        cp infrastructure/terraform.tfvars ${BACKUP_DIR}/
        print_success "Terraform variables backed up to ${BACKUP_DIR}/"
    fi
    
    print_success "Data backup completed!"
}

# Function to destroy SageMaker resources first
destroy_sagemaker_resources() {
    print_status "Destroying SageMaker resources..."
    
    # Delete SageMaker endpoint
    ENDPOINT_NAME="${PROJECT_NAME}-${ENVIRONMENT}-endpoint"
    if aws sagemaker describe-endpoint --endpoint-name ${ENDPOINT_NAME} &> /dev/null; then
        print_status "Deleting SageMaker endpoint: ${ENDPOINT_NAME}"
        aws sagemaker delete-endpoint --endpoint-name ${ENDPOINT_NAME}
        
        # Wait for endpoint to be deleted
        print_status "Waiting for SageMaker endpoint to be deleted..."
        aws sagemaker wait endpoint-deleted --endpoint-name ${ENDPOINT_NAME}
        print_success "SageMaker endpoint deleted!"
    fi
    
    # Delete SageMaker endpoint configuration
    ENDPOINT_CONFIG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-endpoint-config"
    if aws sagemaker describe-endpoint-config --endpoint-config-name ${ENDPOINT_CONFIG_NAME} &> /dev/null; then
        print_status "Deleting SageMaker endpoint configuration: ${ENDPOINT_CONFIG_NAME}"
        aws sagemaker delete-endpoint-config --endpoint-config-name ${ENDPOINT_CONFIG_NAME}
        print_success "SageMaker endpoint configuration deleted!"
    fi
    
    # Delete SageMaker model
    MODEL_NAME="${PROJECT_NAME}-${ENVIRONMENT}-model"
    if aws sagemaker describe-model --model-name ${MODEL_NAME} &> /dev/null; then
        print_status "Deleting SageMaker model: ${MODEL_NAME}"
        aws sagemaker delete-model --model-name ${MODEL_NAME}
        print_success "SageMaker model deleted!"
    fi
}

# Function to destroy Redshift cluster
destroy_redshift_cluster() {
    print_status "Destroying Redshift cluster..."
    
    CLUSTER_IDENTIFIER="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
    if aws redshift describe-clusters --cluster-identifier ${CLUSTER_IDENTIFIER} &> /dev/null; then
        print_status "Deleting Redshift cluster: ${CLUSTER_IDENTIFIER}"
        aws redshift delete-cluster \
            --cluster-identifier ${CLUSTER_IDENTIFIER} \
            --skip-final-cluster-snapshot
        
        # Wait for cluster to be deleted
        print_status "Waiting for Redshift cluster to be deleted..."
        aws redshift wait cluster-deleted --cluster-identifier ${CLUSTER_IDENTIFIER}
        print_success "Redshift cluster deleted!"
    fi
}

# Function to destroy Kinesis streams
destroy_kinesis_streams() {
    print_status "Destroying Kinesis streams..."
    
    # Delete data stream
    DATA_STREAM_NAME="${PROJECT_NAME}-${ENVIRONMENT}-data-stream"
    if aws kinesis describe-stream --stream-name ${DATA_STREAM_NAME} &> /dev/null; then
        print_status "Deleting Kinesis data stream: ${DATA_STREAM_NAME}"
        aws kinesis delete-stream --stream-name ${DATA_STREAM_NAME}
        print_success "Kinesis data stream deleted!"
    fi
    
    # Delete processed stream
    PROCESSED_STREAM_NAME="${PROJECT_NAME}-${ENVIRONMENT}-processed-stream"
    if aws kinesis describe-stream --stream-name ${PROCESSED_STREAM_NAME} &> /dev/null; then
        print_status "Deleting Kinesis processed stream: ${PROCESSED_STREAM_NAME}"
        aws kinesis delete-stream --stream-name ${PROCESSED_STREAM_NAME}
        print_success "Kinesis processed stream deleted!"
    fi
}

# Function to destroy S3 buckets
destroy_s3_buckets() {
    print_status "Destroying S3 buckets..."
    
    # Get list of buckets to delete
    BUCKETS=$(aws s3api list-buckets --query "Buckets[?contains(Name, '${PROJECT_NAME}-${ENVIRONMENT}')].Name" --output text)
    
    for bucket in $BUCKETS; do
        print_status "Deleting S3 bucket: ${bucket}"
        
        # Delete all objects in the bucket
        aws s3 rm s3://${bucket} --recursive
        
        # Delete the bucket
        aws s3api delete-bucket --bucket ${bucket}
        
        print_success "S3 bucket deleted: ${bucket}"
    done
}

# Function to destroy Lambda functions
destroy_lambda_functions() {
    print_status "Destroying Lambda functions..."
    
    # Get list of Lambda functions to delete
    FUNCTIONS=$(aws lambda list-functions --query "Functions[?contains(FunctionName, '${PROJECT_NAME}-${ENVIRONMENT}')].FunctionName" --output text)
    
    for function in $FUNCTIONS; do
        print_status "Deleting Lambda function: ${function}"
        aws lambda delete-function --function-name ${function}
        print_success "Lambda function deleted: ${function}"
    done
}

# Function to destroy infrastructure with Terraform
destroy_infrastructure() {
    print_status "Destroying infrastructure with Terraform..."
    
    cd infrastructure
    
    # Destroy infrastructure
    terraform destroy -auto-approve
    
    print_success "Infrastructure destroyed with Terraform!"
}

# Function to clean up remaining resources
cleanup_remaining_resources() {
    print_status "Cleaning up remaining resources..."
    
    # Delete CloudWatch log groups
    LOG_GROUPS=$(aws logs describe-log-groups --query "logGroups[?contains(logGroupName, '${PROJECT_NAME}-${ENVIRONMENT}')].logGroupName" --output text)
    
    for log_group in $LOG_GROUPS; do
        print_status "Deleting CloudWatch log group: ${log_group}"
        aws logs delete-log-group --log-group-name ${log_group}
        print_success "CloudWatch log group deleted: ${log_group}"
    done
    
    # Delete SNS topics
    SNS_TOPICS=$(aws sns list-topics --query "Topics[?contains(TopicArn, '${PROJECT_NAME}-${ENVIRONMENT}')].TopicArn" --output text)
    
    for topic in $SNS_TOPICS; do
        print_status "Deleting SNS topic: ${topic}"
        aws sns delete-topic --topic-arn ${topic}
        print_success "SNS topic deleted: ${topic}"
    done
    
    # Delete IAM roles
    IAM_ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, '${PROJECT_NAME}-${ENVIRONMENT}')].RoleName" --output text)
    
    for role in $IAM_ROLES; do
        print_status "Deleting IAM role: ${role}"
        
        # Detach policies
        POLICIES=$(aws iam list-attached-role-policies --role-name ${role} --query "AttachedPolicies[].PolicyArn" --output text)
        for policy in $POLICIES; do
            aws iam detach-role-policy --role-name ${role} --policy-arn ${policy}
        done
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies --role-name ${role} --query "PolicyNames" --output text)
        for policy in $INLINE_POLICIES; do
            aws iam delete-role-policy --role-name ${role} --policy-name ${policy}
        done
        
        # Delete the role
        aws iam delete-role --role-name ${role}
        print_success "IAM role deleted: ${role}"
    done
    
    print_success "Remaining resources cleaned up!"
}

# Function to display destruction summary
display_destruction_summary() {
    print_status "Destruction Summary:"
    
    echo ""
    echo "=== DESTRUCTION COMPLETED ==="
    echo "Project: ${PROJECT_NAME}"
    echo "Environment: ${ENVIRONMENT}"
    echo ""
    echo "The following resources have been destroyed:"
    echo "- SageMaker endpoints and models"
    echo "- Redshift clusters"
    echo "- Kinesis data streams"
    echo "- S3 buckets and objects"
    echo "- Lambda functions"
    echo "- CloudWatch log groups"
    echo "- SNS topics"
    echo "- IAM roles and policies"
    echo "- VPC and networking resources"
    echo "- All other infrastructure components"
    echo ""
    
    print_success "Destruction completed successfully!"
}

# Main destruction function
main() {
    echo "=========================================="
    echo "  Data Analytics ML Platform Destruction"
    echo "=========================================="
    echo ""
    
    # Warning message
    print_warning "WARNING: This will permanently destroy all resources!"
    print_warning "This action cannot be undone!"
    echo ""
    
    # Ask for confirmation
    read -p "Are you sure you want to destroy the entire platform? (yes/NO): " -r
    echo ""
    
    if [[ $REPLY != "yes" ]]; then
        print_warning "Destruction cancelled by user."
        exit 0
    fi
    
    # Ask for final confirmation
    read -p "Type 'DESTROY' to confirm: " -r
    echo ""
    
    if [[ $REPLY != "DESTROY" ]]; then
        print_warning "Destruction cancelled by user."
        exit 0
    fi
    
    check_prerequisites
    backup_data
    destroy_sagemaker_resources
    destroy_redshift_cluster
    destroy_kinesis_streams
    destroy_s3_buckets
    destroy_lambda_functions
    destroy_infrastructure
    cleanup_remaining_resources
    display_destruction_summary
}

# Run main function
main "$@"
