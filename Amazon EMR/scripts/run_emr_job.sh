#!/bin/bash
# EMR Job Execution Script
# Provides three methods to run EMR jobs as mentioned in the tutorial

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

# Default values
CLUSTER_ID=""
JOB_TYPE="spark"
SCRIPT_PATH=""
INPUT_PATH=""
OUTPUT_PATH=""
AWS_REGION="us-east-1"
MONITOR_TIMEOUT=30

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

EMR Job Execution Script - Three Methods to Run EMR Jobs

OPTIONS:
    -c, --cluster-id ID       EMR Cluster ID (required)
    -j, --job-type TYPE      Job type (spark|python|hive) (default: spark)
    -s, --script-path PATH   S3 path to script (required)
    -i, --input-path PATH    S3 input data path
    -o, --output-path PATH  S3 output data path
    -r, --region REGION      AWS region (default: us-east-1)
    -m, --monitor            Monitor job execution
    -t, --timeout MINUTES    Monitor timeout in minutes (default: 30)
    -h, --help              Show this help message

EXAMPLES:
    # Method 1: Run Spark job via CLI
    $0 --cluster-id j-1234567890 --job-type spark --script-path s3://bucket/scripts/spark_job.py

    # Method 2: Run Python job with monitoring
    $0 --cluster-id j-1234567890 --job-type python --script-path s3://bucket/scripts/data_processor.py --monitor

    # Method 3: Run Hive job
    $0 --cluster-id j-1234567890 --job-type hive --script-path s3://bucket/scripts/hive_job.sql

METHODS TO TRIGGER EMR STEPS:
    1. Console-based: Manual job submission via AWS Console
    2. CLI-based: This script (AWS CLI command execution)
    3. API-based: Programmatic job submission using boto3

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cluster-id)
            CLUSTER_ID="$2"
            shift 2
            ;;
        -j|--job-type)
            JOB_TYPE="$2"
            shift 2
            ;;
        -s|--script-path)
            SCRIPT_PATH="$2"
            shift 2
            ;;
        -i|--input-path)
            INPUT_PATH="$2"
            shift 2
            ;;
        -o|--output-path)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -m|--monitor)
            MONITOR="true"
            shift
            ;;
        -t|--timeout)
            MONITOR_TIMEOUT="$2"
            shift 2
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

# Validate required parameters
if [[ -z "$CLUSTER_ID" ]]; then
    print_error "Cluster ID is required. Use --cluster-id option."
    exit 1
fi

if [[ -z "$SCRIPT_PATH" ]]; then
    print_error "Script path is required. Use --script-path option."
    exit 1
fi

# Validate job type
if [[ ! "$JOB_TYPE" =~ ^(spark|python|hive)$ ]]; then
    print_error "Invalid job type: $JOB_TYPE. Must be spark, python, or hive."
    exit 1
fi

# Function to create step configuration
create_step_config() {
    local job_type="$1"
    local script_path="$2"
    local input_path="$3"
    local output_path="$4"
    
    case $job_type in
        spark)
            # Spark job configuration
            local step_args=(
                "spark-submit"
                "--deploy-mode" "cluster"
                "--executor-memory" "2g"
                "--executor-cores" "2"
                "--num-executors" "2"
            )
            
            if [[ -n "$input_path" ]]; then
                step_args+=("--input-path" "$input_path")
            fi
            
            if [[ -n "$output_path" ]]; then
                step_args+=("--output-path" "$output_path")
            fi
            
            step_args+=("$script_path")
            ;;
            
        python)
            # Python job configuration
            local step_args=("python3" "$script_path")
            
            if [[ -n "$input_path" ]]; then
                step_args+=("--input-path" "$input_path")
            fi
            
            if [[ -n "$output_path" ]]; then
                step_args+=("--output-path" "$output_path")
            fi
            ;;
            
        hive)
            # Hive job configuration
            local step_args=(
                "hive-script"
                "--run-hive-script"
                "--args"
                "-f" "$script_path"
            )
            ;;
    esac
    
    # Create step configuration JSON
    cat << EOF
{
    "Name": "${job_type^} Data Processing - $(date +%Y%m%d_%H%M%S)",
    "ActionOnFailure": "CONTINUE",
    "HadoopJarStep": {
        "Jar": "command-runner.jar",
        "Args": $(printf '%s\n' "${step_args[@]}" | jq -R . | jq -s .)
    }
}
EOF
}

# Function to submit step
submit_step() {
    local step_config="$1"
    
    print_status "Submitting $JOB_TYPE job to cluster $CLUSTER_ID..."
    
    # Submit step using AWS CLI
    local response=$(aws emr add-job-flow-steps \
        --cluster-id "$CLUSTER_ID" \
        --steps "$step_config" \
        --region "$AWS_REGION" \
        --output json)
    
    if [[ $? -eq 0 ]]; then
        local step_id=$(echo "$response" | jq -r '.StepIds[0]')
        print_success "Step submitted successfully. Step ID: $step_id"
        echo "$step_id"
    else
        print_error "Failed to submit step"
        return 1
    fi
}

# Function to monitor step
monitor_step() {
    local step_id="$1"
    local timeout_minutes="$2"
    
    print_status "Monitoring step $step_id (timeout: ${timeout_minutes} minutes)..."
    
    local start_time=$(date +%s)
    local timeout_seconds=$((timeout_minutes * 60))
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout_seconds ]]; then
            print_warning "Monitoring timed out after $timeout_minutes minutes"
            return 1
        fi
        
        # Get step status
        local status_response=$(aws emr describe-step \
            --cluster-id "$CLUSTER_ID" \
            --step-id "$step_id" \
            --region "$AWS_REGION" \
            --output json)
        
        if [[ $? -eq 0 ]]; then
            local status=$(echo "$status_response" | jq -r '.Step.Status.State')
            print_status "Step status: $status"
            
            case $status in
                COMPLETED)
                    print_success "Step completed successfully!"
                    return 0
                    ;;
                FAILED|CANCELLED)
                    print_error "Step failed with status: $status"
                    
                    # Get failure details
                    local failure_details=$(echo "$status_response" | jq -r '.Step.Status.FailureDetails // empty')
                    if [[ -n "$failure_details" ]]; then
                        print_error "Failure details: $failure_details"
                    fi
                    return 1
                    ;;
                PENDING|RUNNING)
                    print_status "Step is $status. Waiting..."
                    sleep 30
                    ;;
                *)
                    print_warning "Unknown status: $status"
                    sleep 30
                    ;;
            esac
        else
            print_error "Failed to get step status"
            return 1
        fi
    done
}

# Function to get cluster info
get_cluster_info() {
    print_status "Getting cluster information..."
    
    aws emr describe-cluster \
        --cluster-id "$CLUSTER_ID" \
        --region "$AWS_REGION" \
        --query 'Cluster.{Id:Id,Name:Name,Status:Status.State,ReleaseLabel:ReleaseLabel,MasterPublicDns:MasterPublicDnsName}' \
        --output table
}

# Function to list recent steps
list_steps() {
    print_status "Listing recent steps for cluster $CLUSTER_ID..."
    
    aws emr list-steps \
        --cluster-id "$CLUSTER_ID" \
        --region "$AWS_REGION" \
        --query 'Steps[*].{Id:Id,Name:Name,Status:Status.State,Created:Status.Timeline.CreationDateTime}' \
        --output table
}

# Main execution
main() {
    print_status "EMR Job Execution Script"
    print_status "Cluster ID: $CLUSTER_ID"
    print_status "Job Type: $JOB_TYPE"
    print_status "Script Path: $SCRIPT_PATH"
    print_status "Region: $AWS_REGION"
    
    # Get cluster info
    get_cluster_info
    
    # Create step configuration
    print_status "Creating step configuration..."
    local step_config=$(create_step_config "$JOB_TYPE" "$SCRIPT_PATH" "$INPUT_PATH" "$OUTPUT_PATH")
    
    # Submit step
    local step_id=$(submit_step "$step_config")
    
    if [[ -z "$step_id" ]]; then
        print_error "Failed to submit step"
        exit 1
    fi
    
    # Monitor step if requested
    if [[ "$MONITOR" == "true" ]]; then
        monitor_step "$step_id" "$MONITOR_TIMEOUT"
    else
        print_status "Step submitted. Use the following command to monitor:"
        print_status "aws emr describe-step --cluster-id $CLUSTER_ID --step-id $step_id --region $AWS_REGION"
    fi
    
    # Show recent steps
    echo ""
    list_steps
}

# Run main function
main "$@"
