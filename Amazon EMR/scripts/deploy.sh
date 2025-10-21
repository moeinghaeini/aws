#!/bin/bash
# Amazon EMR Big Data Platform Deployment Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INFRASTRUCTURE_DIR="$PROJECT_DIR/infrastructure"
SCRIPTS_DIR="$PROJECT_DIR/scripts"

# Default values
AWS_REGION="us-east-1"
ENVIRONMENT="dev"
ACTION="deploy"
DESTROY_CONFIRM="false"

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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Amazon EMR Big Data Platform Deployment Script

OPTIONS:
    -a, --action ACTION        Action to perform (deploy|destroy|plan|upload-scripts)
                              Default: deploy
    -r, --region REGION       AWS region (default: us-east-1)
    -e, --environment ENV     Environment (dev|staging|prod) (default: dev)
    -c, --confirm             Confirm destruction (required for destroy action)
    -h, --help               Show this help message

EXAMPLES:
    # Deploy infrastructure
    $0 --action deploy --region us-east-1 --environment dev

    # Plan infrastructure changes
    $0 --action plan --region us-east-1 --environment dev

    # Upload scripts to S3
    $0 --action upload-scripts --region us-east-1

    # Destroy infrastructure (with confirmation)
    $0 --action destroy --region us-east-1 --environment dev --confirm

ACTIONS:
    deploy          Deploy the EMR infrastructure
    destroy         Destroy the EMR infrastructure
    plan            Show planned infrastructure changes
    upload-scripts  Upload Spark scripts to S3
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--confirm)
            DESTROY_CONFIRM="true"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate action
if [[ ! "$ACTION" =~ ^(deploy|destroy|plan|upload-scripts)$ ]]; then
    print_error "Invalid action: $ACTION"
    show_usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    exit 1
fi

# Check prerequisites
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
    
    print_success "Prerequisites check passed"
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd "$INFRASTRUCTURE_DIR"
    
    terraform init -upgrade
    
    print_success "Terraform initialized"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying EMR infrastructure..."
    
    cd "$INFRASTRUCTURE_DIR"
    
    # Create terraform.tfvars file
    cat > terraform.tfvars << EOF
aws_region = "$AWS_REGION"
environment = "$ENVIRONMENT"
EOF
    
    # Plan deployment
    print_status "Planning infrastructure deployment..."
    terraform plan -var-file="terraform.tfvars" -out="terraform.tfplan"
    
    # Apply deployment
    print_status "Applying infrastructure deployment..."
    terraform apply "terraform.tfplan"
    
    # Get outputs
    print_status "Getting deployment outputs..."
    terraform output -json > "$PROJECT_DIR/deployment_outputs.json"
    
    print_success "Infrastructure deployed successfully"
}

# Plan infrastructure changes
plan_infrastructure() {
    print_status "Planning infrastructure changes..."
    
    cd "$INFRASTRUCTURE_DIR"
    
    # Create terraform.tfvars file
    cat > terraform.tfvars << EOF
aws_region = "$AWS_REGION"
environment = "$ENVIRONMENT"
EOF
    
    terraform plan -var-file="terraform.tfvars"
}

# Destroy infrastructure
destroy_infrastructure() {
    if [[ "$DESTROY_CONFIRM" != "true" ]]; then
        print_error "Destruction requires confirmation. Use --confirm flag."
        exit 1
    fi
    
    print_warning "This will destroy all EMR infrastructure. Are you sure? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Destruction cancelled"
        exit 0
    fi
    
    print_status "Destroying EMR infrastructure..."
    
    cd "$INFRASTRUCTURE_DIR"
    
    # Create terraform.tfvars file
    cat > terraform.tfvars << EOF
aws_region = "$AWS_REGION"
environment = "$ENVIRONMENT"
EOF
    
    terraform destroy -var-file="terraform.tfvars" -auto-approve
    
    print_success "Infrastructure destroyed"
}

# Upload scripts to S3
upload_scripts() {
    print_status "Uploading scripts to S3..."
    
    # Get S3 bucket name from Terraform outputs
    if [[ ! -f "$PROJECT_DIR/deployment_outputs.json" ]]; then
        print_error "Deployment outputs not found. Please deploy infrastructure first."
        exit 1
    fi
    
    SCRIPTS_BUCKET=$(python3 -c "
import json
with open('$PROJECT_DIR/deployment_outputs.json', 'r') as f:
    outputs = json.load(f)
    print(outputs['scripts_bucket_name']['value'])
")
    
    if [[ -z "$SCRIPTS_BUCKET" ]]; then
        print_error "Could not get scripts bucket name from outputs"
        exit 1
    fi
    
    print_status "Uploading to bucket: $SCRIPTS_BUCKET"
    
    # Upload Spark scripts
    aws s3 cp "$SCRIPTS_DIR/spark_data_processor.py" "s3://$SCRIPTS_BUCKET/scripts/"
    aws s3 cp "$SCRIPTS_DIR/sample_data_generator.py" "s3://$SCRIPTS_BUCKET/scripts/"
    aws s3 cp "$SCRIPTS_DIR/emr_steps.py" "s3://$SCRIPTS_BUCKET/scripts/"
    
    # Upload bootstrap scripts
    aws s3 cp "$SCRIPTS_DIR/bootstrap/" "s3://$SCRIPTS_BUCKET/bootstrap/" --recursive
    
    # Make scripts executable
    aws s3api put-object-acl \
        --bucket "$SCRIPTS_BUCKET" \
        --key "bootstrap/install-python-packages.sh" \
        --acl public-read
    
    print_success "Scripts uploaded successfully"
}

# Generate sample data
generate_sample_data() {
    print_status "Generating sample data..."
    
    # Get S3 bucket name from outputs
    DATA_BUCKET=$(python3 -c "
import json
with open('$PROJECT_DIR/deployment_outputs.json', 'r') as f:
    outputs = json.load(f)
    print(outputs['data_lake_bucket_name']['value'])
")
    
    if [[ -z "$DATA_BUCKET" ]]; then
        print_error "Could not get data bucket name from outputs"
        exit 1
    fi
    
    print_status "Generating sample data in bucket: $DATA_BUCKET"
    
    # Install required Python packages
    pip3 install faker boto3
    
    # Generate sample data
    python3 "$SCRIPTS_DIR/sample_data_generator.py" \
        --bucket-name "$DATA_BUCKET" \
        --data-type both \
        --num-records 1000 \
        --format csv
    
    print_success "Sample data generated"
}

# Main execution
main() {
    print_status "Starting Amazon EMR Big Data Platform deployment"
    print_status "Action: $ACTION"
    print_status "Region: $AWS_REGION"
    print_status "Environment: $ENVIRONMENT"
    
    # Check prerequisites
    check_prerequisites
    
    # Initialize Terraform
    init_terraform
    
    case $ACTION in
        deploy)
            deploy_infrastructure
            upload_scripts
            generate_sample_data
            print_success "Deployment completed successfully!"
            print_status "Check deployment_outputs.json for connection details"
            ;;
        destroy)
            destroy_infrastructure
            ;;
        plan)
            plan_infrastructure
            ;;
        upload-scripts)
            upload_scripts
            ;;
        *)
            print_error "Unknown action: $ACTION"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
