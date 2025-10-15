#!/bin/bash

# Project 6: Data Analytics ML Platform Monitoring Script
# This script provides monitoring and health check capabilities

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

# Function to check Kinesis stream health
check_kinesis_health() {
    print_status "Checking Kinesis stream health..."
    
    STREAM_NAME="${PROJECT_NAME}-${ENVIRONMENT}-data-stream"
    
    if aws kinesis describe-stream --stream-name ${STREAM_NAME} &> /dev/null; then
        # Get stream status
        STATUS=$(aws kinesis describe-stream --stream-name ${STREAM_NAME} --query "StreamDescription.StreamStatus" --output text)
        
        if [ "$STATUS" = "ACTIVE" ]; then
            print_success "Kinesis stream is ACTIVE"
        else
            print_warning "Kinesis stream status: $STATUS"
        fi
        
        # Get shard count
        SHARD_COUNT=$(aws kinesis describe-stream --stream-name ${STREAM_NAME} --query "StreamDescription.Shards | length(@)")
        print_status "Shard count: $SHARD_COUNT"
        
        # Get incoming records metric
        INCOMING_RECORDS=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/Kinesis \
            --metric-name IncomingRecords \
            --dimensions Name=StreamName,Value=${STREAM_NAME} \
            --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
            --period 300 \
            --statistics Sum \
            --query "Datapoints[0].Sum" \
            --output text)
        
        if [ "$INCOMING_RECORDS" != "None" ] && [ "$INCOMING_RECORDS" != "null" ]; then
            print_status "Incoming records (last 5 min): $INCOMING_RECORDS"
        else
            print_warning "No incoming records in the last 5 minutes"
        fi
        
    else
        print_error "Kinesis stream not found: $STREAM_NAME"
    fi
}

# Function to check Redshift cluster health
check_redshift_health() {
    print_status "Checking Redshift cluster health..."
    
    CLUSTER_IDENTIFIER="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
    
    if aws redshift describe-clusters --cluster-identifier ${CLUSTER_IDENTIFIER} &> /dev/null; then
        # Get cluster status
        STATUS=$(aws redshift describe-clusters --cluster-identifier ${CLUSTER_IDENTIFIER} --query "Clusters[0].ClusterStatus" --output text)
        
        if [ "$STATUS" = "available" ]; then
            print_success "Redshift cluster is AVAILABLE"
        else
            print_warning "Redshift cluster status: $STATUS"
        fi
        
        # Get cluster endpoint
        ENDPOINT=$(aws redshift describe-clusters --cluster-identifier ${CLUSTER_IDENTIFIER} --query "Clusters[0].Endpoint.Address" --output text)
        print_status "Cluster endpoint: $ENDPOINT"
        
        # Get CPU utilization
        CPU_UTILIZATION=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/Redshift \
            --metric-name CPUUtilization \
            --dimensions Name=ClusterIdentifier,Value=${CLUSTER_IDENTIFIER} \
            --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
            --period 300 \
            --statistics Average \
            --query "Datapoints[0].Average" \
            --output text)
        
        if [ "$CPU_UTILIZATION" != "None" ] && [ "$CPU_UTILIZATION" != "null" ]; then
            print_status "CPU utilization: ${CPU_UTILIZATION}%"
        else
            print_warning "No CPU utilization data available"
        fi
        
    else
        print_error "Redshift cluster not found: $CLUSTER_IDENTIFIER"
    fi
}

# Function to check SageMaker endpoint health
check_sagemaker_health() {
    print_status "Checking SageMaker endpoint health..."
    
    ENDPOINT_NAME="${PROJECT_NAME}-${ENVIRONMENT}-endpoint"
    
    if aws sagemaker describe-endpoint --endpoint-name ${ENDPOINT_NAME} &> /dev/null; then
        # Get endpoint status
        STATUS=$(aws sagemaker describe-endpoint --endpoint-name ${ENDPOINT_NAME} --query "EndpointStatus" --output text)
        
        if [ "$STATUS" = "InService" ]; then
            print_success "SageMaker endpoint is IN SERVICE"
        else
            print_warning "SageMaker endpoint status: $STATUS"
        fi
        
        # Get model latency
        MODEL_LATENCY=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/SageMaker \
            --metric-name ModelLatency \
            --dimensions Name=EndpointName,Value=${ENDPOINT_NAME} \
            --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
            --period 300 \
            --statistics Average \
            --query "Datapoints[0].Average" \
            --output text)
        
        if [ "$MODEL_LATENCY" != "None" ] && [ "$MODEL_LATENCY" != "null" ]; then
            print_status "Model latency: ${MODEL_LATENCY}ms"
        else
            print_warning "No model latency data available"
        fi
        
        # Get invocation errors
        INVOCATION_ERRORS=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/SageMaker \
            --metric-name Invocation5XXErrors \
            --dimensions Name=EndpointName,Value=${ENDPOINT_NAME} \
            --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
            --period 300 \
            --statistics Sum \
            --query "Datapoints[0].Sum" \
            --output text)
        
        if [ "$INVOCATION_ERRORS" != "None" ] && [ "$INVOCATION_ERRORS" != "null" ]; then
            if [ "$INVOCATION_ERRORS" = "0" ]; then
                print_success "No 5XX errors in the last 5 minutes"
            else
                print_warning "5XX errors in the last 5 minutes: $INVOCATION_ERRORS"
            fi
        else
            print_warning "No invocation error data available"
        fi
        
    else
        print_error "SageMaker endpoint not found: $ENDPOINT_NAME"
    fi
}

# Function to check Lambda function health
check_lambda_health() {
    print_status "Checking Lambda function health..."
    
    # Get list of Lambda functions
    FUNCTIONS=$(aws lambda list-functions --query "Functions[?contains(FunctionName, '${PROJECT_NAME}-${ENVIRONMENT}')].FunctionName" --output text)
    
    for function in $FUNCTIONS; do
        print_status "Checking function: $function"
        
        # Get function configuration
        CONFIG=$(aws lambda get-function-configuration --function-name $function)
        STATE=$(echo $CONFIG | jq -r '.State')
        LAST_MODIFIED=$(echo $CONFIG | jq -r '.LastModified')
        
        if [ "$STATE" = "Active" ]; then
            print_success "Function $function is ACTIVE"
        else
            print_warning "Function $function state: $STATE"
        fi
        
        print_status "Last modified: $LAST_MODIFIED"
        
        # Get error count
        ERROR_COUNT=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/Lambda \
            --metric-name Errors \
            --dimensions Name=FunctionName,Value=${function} \
            --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
            --period 300 \
            --statistics Sum \
            --query "Datapoints[0].Sum" \
            --output text)
        
        if [ "$ERROR_COUNT" != "None" ] && [ "$ERROR_COUNT" != "null" ]; then
            if [ "$ERROR_COUNT" = "0" ]; then
                print_success "No errors in the last 5 minutes"
            else
                print_warning "Errors in the last 5 minutes: $ERROR_COUNT"
            fi
        else
            print_warning "No error data available"
        fi
        
        # Get duration
        DURATION=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/Lambda \
            --metric-name Duration \
            --dimensions Name=FunctionName,Value=${function} \
            --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
            --period 300 \
            --statistics Average \
            --query "Datapoints[0].Average" \
            --output text)
        
        if [ "$DURATION" != "None" ] && [ "$DURATION" != "null" ]; then
            print_status "Average duration: ${DURATION}ms"
        else
            print_warning "No duration data available"
        fi
        
        echo ""
    done
}

# Function to check CloudWatch alarms
check_cloudwatch_alarms() {
    print_status "Checking CloudWatch alarms..."
    
    # Get list of alarms
    ALARMS=$(aws cloudwatch describe-alarms --query "MetricAlarms[?contains(AlarmName, '${PROJECT_NAME}-${ENVIRONMENT}')].AlarmName" --output text)
    
    if [ -z "$ALARMS" ]; then
        print_warning "No alarms found for this project"
        return
    fi
    
    for alarm in $ALARMS; do
        ALARM_STATE=$(aws cloudwatch describe-alarms --alarm-names $alarm --query "MetricAlarms[0].StateValue" --output text)
        
        if [ "$ALARM_STATE" = "OK" ]; then
            print_success "Alarm $alarm is OK"
        else
            print_warning "Alarm $alarm state: $ALARM_STATE"
        fi
    done
}

# Function to check S3 bucket health
check_s3_health() {
    print_status "Checking S3 bucket health..."
    
    # Get list of buckets
    BUCKETS=$(aws s3api list-buckets --query "Buckets[?contains(Name, '${PROJECT_NAME}-${ENVIRONMENT}')].Name" --output text)
    
    for bucket in $BUCKETS; do
        print_status "Checking bucket: $bucket"
        
        # Check if bucket exists and is accessible
        if aws s3api head-bucket --bucket $bucket &> /dev/null; then
            print_success "Bucket $bucket is accessible"
            
            # Get object count
            OBJECT_COUNT=$(aws s3api list-objects-v2 --bucket $bucket --query "KeyCount" --output text)
            print_status "Object count: $OBJECT_COUNT"
            
            # Get bucket size
            BUCKET_SIZE=$(aws s3api list-objects-v2 --bucket $bucket --query "Contents[].Size" --output text | awk '{sum+=$1} END {print sum/1024/1024 " MB"}')
            print_status "Bucket size: $BUCKET_SIZE"
            
        else
            print_error "Bucket $bucket is not accessible"
        fi
        
        echo ""
    done
}

# Function to generate health report
generate_health_report() {
    print_status "Generating health report..."
    
    REPORT_FILE="health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "  Data Analytics ML Platform Health Report"
        echo "=========================================="
        echo "Generated: $(date)"
        echo "Project: $PROJECT_NAME"
        echo "Environment: $ENVIRONMENT"
        echo "Region: $AWS_REGION"
        echo ""
        
        echo "=== KINESIS STREAM HEALTH ==="
        check_kinesis_health
        echo ""
        
        echo "=== REDSHIFT CLUSTER HEALTH ==="
        check_redshift_health
        echo ""
        
        echo "=== SAGEMAKER ENDPOINT HEALTH ==="
        check_sagemaker_health
        echo ""
        
        echo "=== LAMBDA FUNCTION HEALTH ==="
        check_lambda_health
        echo ""
        
        echo "=== CLOUDWATCH ALARMS ==="
        check_cloudwatch_alarms
        echo ""
        
        echo "=== S3 BUCKET HEALTH ==="
        check_s3_health
        echo ""
        
    } > $REPORT_FILE
    
    print_success "Health report generated: $REPORT_FILE"
}

# Function to display monitoring dashboard
display_dashboard() {
    print_status "Monitoring Dashboard:"
    
    echo ""
    echo "=========================================="
    echo "  Data Analytics ML Platform Dashboard"
    echo "=========================================="
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Last Updated: $(date)"
    echo ""
    
    # Quick status overview
    echo "=== QUICK STATUS ==="
    
    # Kinesis status
    STREAM_NAME="${PROJECT_NAME}-${ENVIRONMENT}-data-stream"
    if aws kinesis describe-stream --stream-name ${STREAM_NAME} &> /dev/null; then
        KINESIS_STATUS=$(aws kinesis describe-stream --stream-name ${STREAM_NAME} --query "StreamDescription.StreamStatus" --output text)
        echo "Kinesis Stream: $KINESIS_STATUS"
    else
        echo "Kinesis Stream: NOT FOUND"
    fi
    
    # Redshift status
    CLUSTER_IDENTIFIER="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
    if aws redshift describe-clusters --cluster-identifier ${CLUSTER_IDENTIFIER} &> /dev/null; then
        REDSHIFT_STATUS=$(aws redshift describe-clusters --cluster-identifier ${CLUSTER_IDENTIFIER} --query "Clusters[0].ClusterStatus" --output text)
        echo "Redshift Cluster: $REDSHIFT_STATUS"
    else
        echo "Redshift Cluster: NOT FOUND"
    fi
    
    # SageMaker status
    ENDPOINT_NAME="${PROJECT_NAME}-${ENVIRONMENT}-endpoint"
    if aws sagemaker describe-endpoint --endpoint-name ${ENDPOINT_NAME} &> /dev/null; then
        SAGEMAKER_STATUS=$(aws sagemaker describe-endpoint --endpoint-name ${ENDPOINT_NAME} --query "EndpointStatus" --output text)
        echo "SageMaker Endpoint: $SAGEMAKER_STATUS"
    else
        echo "SageMaker Endpoint: NOT FOUND"
    fi
    
    echo ""
    echo "=== USEFUL COMMANDS ==="
    echo "View CloudWatch Dashboard: aws cloudwatch get-dashboard --dashboard-name ${PROJECT_NAME}-${ENVIRONMENT}-dashboard"
    echo "View Kinesis Metrics: aws cloudwatch get-metric-statistics --namespace AWS/Kinesis --metric-name IncomingRecords"
    echo "View Redshift Metrics: aws cloudwatch get-metric-statistics --namespace AWS/Redshift --metric-name CPUUtilization"
    echo "View SageMaker Metrics: aws cloudwatch get-metric-statistics --namespace AWS/SageMaker --metric-name ModelLatency"
    echo ""
}

# Main monitoring function
main() {
    case "${1:-dashboard}" in
        "kinesis")
            check_kinesis_health
            ;;
        "redshift")
            check_redshift_health
            ;;
        "sagemaker")
            check_sagemaker_health
            ;;
        "lambda")
            check_lambda_health
            ;;
        "alarms")
            check_cloudwatch_alarms
            ;;
        "s3")
            check_s3_health
            ;;
        "report")
            generate_health_report
            ;;
        "dashboard"|*)
            display_dashboard
            ;;
    esac
}

# Run main function
main "$@"
