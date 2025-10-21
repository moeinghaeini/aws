"""
Data Quality Checker Lambda Function
Monitors data quality and sends alerts for anomalies
"""

import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
redshift_client = boto3.client('redshift-data')
sns_client = boto3.client('sns')
cloudwatch_client = boto3.client('cloudwatch')

# Environment variables
REDSHIFT_CLUSTER_ID = os.environ.get('REDSHIFT_CLUSTER_ID')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for data quality checks
    """
    try:
        logger.info("Starting data quality checks")
        
        # Perform various data quality checks
        checks = {
            'record_count_check': check_record_count(),
            'data_freshness_check': check_data_freshness(),
            'data_completeness_check': check_data_completeness(),
            'data_consistency_check': check_data_consistency(),
            'anomaly_detection': detect_anomalies()
        }
        
        # Analyze results
        results = analyze_quality_results(checks)
        
        # Send alerts if needed
        if results['has_issues']:
            send_quality_alert(results)
        
        # Publish metrics to CloudWatch
        publish_quality_metrics(results)
        
        logger.info(f"Data quality checks completed. Issues found: {results['has_issues']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Data quality checks completed',
                'results': results,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error in data quality checker: {str(e)}")
        send_error_alert(str(e))
        raise e

def check_record_count() -> Dict[str, Any]:
    """
    Check if record count is within expected range
    """
    try:
        # Get record count for last hour
        sql = """
        SELECT COUNT(*) as record_count
        FROM events 
        WHERE processed_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour';
        """
        
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER_ID,
            Database='analytics',
            Sql=sql
        )
        
        # Note: In a real implementation, you'd need to poll for the result
        # This is a simplified version
        record_count = 1000  # Mock value
        
        # Expected range: 500-2000 records per hour
        min_expected = 500
        max_expected = 2000
        
        is_healthy = min_expected <= record_count <= max_expected
        
        return {
            'check_name': 'record_count_check',
            'status': 'PASS' if is_healthy else 'FAIL',
            'value': record_count,
            'expected_range': f"{min_expected}-{max_expected}",
            'message': f"Record count: {record_count} (expected: {min_expected}-{max_expected})"
        }
        
    except Exception as e:
        logger.error(f"Error in record count check: {str(e)}")
        return {
            'check_name': 'record_count_check',
            'status': 'ERROR',
            'error': str(e)
        }

def check_data_freshness() -> Dict[str, Any]:
    """
    Check if data is being processed in a timely manner
    """
    try:
        # Get latest record timestamp
        sql = """
        SELECT MAX(processed_at) as latest_processed
        FROM events;
        """
        
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER_ID,
            Database='analytics',
            Sql=sql
        )
        
        # Mock latest processed time (1 minute ago)
        latest_processed = datetime.utcnow() - timedelta(minutes=1)
        
        # Check if data is fresh (within last 5 minutes)
        time_diff = datetime.utcnow() - latest_processed
        is_fresh = time_diff.total_seconds() < 300  # 5 minutes
        
        return {
            'check_name': 'data_freshness_check',
            'status': 'PASS' if is_fresh else 'FAIL',
            'value': latest_processed.isoformat(),
            'threshold': '5 minutes',
            'message': f"Latest data: {latest_processed.isoformat()} (threshold: 5 minutes)"
        }
        
    except Exception as e:
        logger.error(f"Error in data freshness check: {str(e)}")
        return {
            'check_name': 'data_freshness_check',
            'status': 'ERROR',
            'error': str(e)
        }

def check_data_completeness() -> Dict[str, Any]:
    """
    Check for missing or null values in critical fields
    """
    try:
        # Check for null values in critical fields
        sql = """
        SELECT 
            COUNT(*) as total_records,
            COUNT(CASE WHEN user_id IS NULL THEN 1 END) as null_user_ids,
            COUNT(CASE WHEN event_type IS NULL THEN 1 END) as null_event_types,
            COUNT(CASE WHEN timestamp IS NULL THEN 1 END) as null_timestamps
        FROM events 
        WHERE processed_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour';
        """
        
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER_ID,
            Database='analytics',
            Sql=sql
        )
        
        # Mock values
        total_records = 1000
        null_user_ids = 5
        null_event_types = 2
        null_timestamps = 0
        
        # Calculate completeness percentage
        completeness = ((total_records - null_user_ids - null_event_types - null_timestamps) / total_records) * 100
        
        # Threshold: 95% completeness
        is_complete = completeness >= 95.0
        
        return {
            'check_name': 'data_completeness_check',
            'status': 'PASS' if is_complete else 'FAIL',
            'value': f"{completeness:.2f}%",
            'threshold': '95%',
            'details': {
                'total_records': total_records,
                'null_user_ids': null_user_ids,
                'null_event_types': null_event_types,
                'null_timestamps': null_timestamps
            },
            'message': f"Data completeness: {completeness:.2f}% (threshold: 95%)"
        }
        
    except Exception as e:
        logger.error(f"Error in data completeness check: {str(e)}")
        return {
            'check_name': 'data_completeness_check',
            'status': 'ERROR',
            'error': str(e)
        }

def check_data_consistency() -> Dict[str, Any]:
    """
    Check for data consistency issues
    """
    try:
        # Check for duplicate records
        sql = """
        SELECT 
            user_id, event_type, timestamp, COUNT(*) as duplicate_count
        FROM events 
        WHERE processed_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        GROUP BY user_id, event_type, timestamp
        HAVING COUNT(*) > 1;
        """
        
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER_ID,
            Database='analytics',
            Sql=sql
        )
        
        # Mock duplicate count
        duplicate_count = 3
        
        # Threshold: No more than 5 duplicates per hour
        is_consistent = duplicate_count <= 5
        
        return {
            'check_name': 'data_consistency_check',
            'status': 'PASS' if is_consistent else 'FAIL',
            'value': duplicate_count,
            'threshold': '5',
            'message': f"Duplicate records: {duplicate_count} (threshold: 5)"
        }
        
    except Exception as e:
        logger.error(f"Error in data consistency check: {str(e)}")
        return {
            'check_name': 'data_consistency_check',
            'status': 'ERROR',
            'error': str(e)
        }

def detect_anomalies() -> Dict[str, Any]:
    """
    Detect anomalies in data patterns
    """
    try:
        # Check for unusual spikes in event volume
        sql = """
        SELECT 
            DATE_TRUNC('minute', processed_at) as minute,
            COUNT(*) as event_count
        FROM events 
        WHERE processed_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        GROUP BY DATE_TRUNC('minute', processed_at)
        ORDER BY minute;
        """
        
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER_ID,
            Database='analytics',
            Sql=sql
        )
        
        # Mock anomaly detection
        avg_events_per_minute = 20
        max_events_per_minute = 45
        min_events_per_minute = 5
        
        # Check for spikes (more than 2x average) or drops (less than 0.5x average)
        has_spike = max_events_per_minute > (avg_events_per_minute * 2)
        has_drop = min_events_per_minute < (avg_events_per_minute * 0.5)
        
        has_anomaly = has_spike or has_drop
        
        return {
            'check_name': 'anomaly_detection',
            'status': 'PASS' if not has_anomaly else 'FAIL',
            'value': {
                'avg_events_per_minute': avg_events_per_minute,
                'max_events_per_minute': max_events_per_minute,
                'min_events_per_minute': min_events_per_minute,
                'has_spike': has_spike,
                'has_drop': has_drop
            },
            'message': f"Anomaly detected: spike={has_spike}, drop={has_drop}"
        }
        
    except Exception as e:
        logger.error(f"Error in anomaly detection: {str(e)}")
        return {
            'check_name': 'anomaly_detection',
            'status': 'ERROR',
            'error': str(e)
        }

def analyze_quality_results(checks: Dict[str, Any]) -> Dict[str, Any]:
    """
    Analyze the results of all quality checks
    """
    failed_checks = []
    error_checks = []
    
    for check_name, result in checks.items():
        if result['status'] == 'FAIL':
            failed_checks.append(result)
        elif result['status'] == 'ERROR':
            error_checks.append(result)
    
    has_issues = len(failed_checks) > 0 or len(error_checks) > 0
    
    return {
        'has_issues': has_issues,
        'total_checks': len(checks),
        'passed_checks': len(checks) - len(failed_checks) - len(error_checks),
        'failed_checks': len(failed_checks),
        'error_checks': len(error_checks),
        'failed_check_details': failed_checks,
        'error_check_details': error_checks,
        'overall_status': 'HEALTHY' if not has_issues else 'UNHEALTHY'
    }

def send_quality_alert(results: Dict[str, Any]) -> None:
    """
    Send alert about data quality issues
    """
    try:
        message = f"""
Data Quality Alert - {datetime.utcnow().isoformat()}

Overall Status: {results['overall_status']}
Failed Checks: {results['failed_checks']}
Error Checks: {results['error_checks']}

Failed Check Details:
{json.dumps(results['failed_check_details'], indent=2)}

Error Check Details:
{json.dumps(results['error_check_details'], indent=2)}

Please investigate these data quality issues.
        """
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"Data Quality Alert - {results['overall_status']}",
            Message=message
        )
        
        logger.info("Data quality alert sent")
        
    except Exception as e:
        logger.error(f"Error sending quality alert: {str(e)}")

def send_error_alert(error_message: str) -> None:
    """
    Send alert about data quality checker errors
    """
    try:
        message = f"""
Data Quality Checker Error - {datetime.utcnow().isoformat()}

Error: {error_message}

The data quality checker encountered an error and could not complete its checks.
Please investigate the issue.
        """
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="Data Quality Checker Error",
            Message=message
        )
        
        logger.info("Error alert sent")
        
    except Exception as e:
        logger.error(f"Error sending error alert: {str(e)}")

def publish_quality_metrics(results: Dict[str, Any]) -> None:
    """
    Publish data quality metrics to CloudWatch
    """
    try:
        metrics = [
            {
                'MetricName': 'DataQualityOverallStatus',
                'Value': 1 if results['overall_status'] == 'HEALTHY' else 0,
                'Unit': 'Count'
            },
            {
                'MetricName': 'DataQualityFailedChecks',
                'Value': results['failed_checks'],
                'Unit': 'Count'
            },
            {
                'MetricName': 'DataQualityErrorChecks',
                'Value': results['error_checks'],
                'Unit': 'Count'
            }
        ]
        
        cloudwatch_client.put_metric_data(
            Namespace='DataAnalytics/DataQuality',
            MetricData=metrics
        )
        
        logger.info("Quality metrics published to CloudWatch")
        
    except Exception as e:
        logger.error(f"Error publishing quality metrics: {str(e)}")
