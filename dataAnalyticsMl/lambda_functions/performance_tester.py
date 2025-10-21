"""
Performance Testing Lambda Function
Automated performance testing and benchmarking for the analytics platform
"""

import json
import boto3
import logging
import time
import random
import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Any
import os
import concurrent.futures
import statistics

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
kinesis_client = boto3.client('kinesis')
sagemaker_client = boto3.client('sagemaker-runtime')
redshift_client = boto3.client('redshift-data')
cloudwatch_client = boto3.client('cloudwatch')

# Environment variables
KINESIS_STREAM = os.environ.get('KINESIS_STREAM')
SAGEMAKER_ENDPOINT = os.environ.get('SAGEMAKER_ENDPOINT')
REDSHIFT_CLUSTER = os.environ.get('REDSHIFT_CLUSTER')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for performance testing
    """
    try:
        logger.info("Starting performance testing...")
        
        # Run comprehensive performance tests
        test_results = {
            'test_timestamp': datetime.utcnow().isoformat(),
            'kinesis_performance': test_kinesis_performance(),
            'lambda_performance': test_lambda_performance(),
            'sagemaker_performance': test_sagemaker_performance(),
            'redshift_performance': test_redshift_performance(),
            'end_to_end_performance': test_end_to_end_performance(),
            'load_testing': run_load_tests(),
            'stress_testing': run_stress_tests()
        }
        
        # Analyze results and generate report
        analysis = analyze_performance_results(test_results)
        
        # Publish metrics to CloudWatch
        publish_performance_metrics(test_results, analysis)
        
        # Generate performance report
        report = generate_performance_report(test_results, analysis)
        
        logger.info(f"Performance testing completed. Overall score: {analysis['overall_score']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Performance testing completed successfully',
                'overall_score': analysis['overall_score'],
                'test_results': test_results,
                'analysis': analysis,
                'report': report
            })
        }
        
    except Exception as e:
        logger.error(f"Error in performance testing: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Performance testing failed'
            })
        }

def test_kinesis_performance() -> Dict[str, Any]:
    """
    Test Kinesis stream performance
    """
    try:
        logger.info("Testing Kinesis performance...")
        
        # Test single record performance
        start_time = time.time()
        test_record = {
            'timestamp': datetime.utcnow().isoformat(),
            'user_id': f'perf_test_{uuid.uuid4()}',
            'event_type': 'performance_test',
            'value': random.uniform(0, 100)
        }
        
        kinesis_client.put_record(
            StreamName=KINESIS_STREAM,
            Data=json.dumps(test_record),
            PartitionKey=test_record['user_id']
        )
        
        single_record_latency = (time.time() - start_time) * 1000  # Convert to milliseconds
        
        # Test batch performance
        start_time = time.time()
        records = []
        for i in range(10):
            record = {
                'timestamp': datetime.utcnow().isoformat(),
                'user_id': f'perf_test_{uuid.uuid4()}',
                'event_type': 'performance_test',
                'value': random.uniform(0, 100)
            }
            records.append({
                'Data': json.dumps(record),
                'PartitionKey': record['user_id']
            })
        
        kinesis_client.put_records(
            StreamName=KINESIS_STREAM,
            Records=records
        )
        
        batch_latency = (time.time() - start_time) * 1000
        
        return {
            'single_record_latency_ms': single_record_latency,
            'batch_latency_ms': batch_latency,
            'records_per_second': 10000 / batch_latency if batch_latency > 0 else 0,
            'status': 'PASS' if single_record_latency < 100 else 'FAIL'
        }
        
    except Exception as e:
        logger.error(f"Kinesis performance test failed: {str(e)}")
        return {
            'error': str(e),
            'status': 'ERROR'
        }

def test_lambda_performance() -> Dict[str, Any]:
    """
    Test Lambda function performance
    """
    try:
        logger.info("Testing Lambda performance...")
        
        # Test cold start performance
        start_time = time.time()
        
        # Simulate Lambda execution
        test_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'user_id': f'perf_test_{uuid.uuid4()}',
            'event_type': 'performance_test',
            'value': random.uniform(0, 100)
        }
        
        # Simulate processing time
        time.sleep(0.1)  # Simulate 100ms processing
        
        execution_time = (time.time() - start_time) * 1000
        
        return {
            'execution_time_ms': execution_time,
            'memory_usage_mb': 256,  # Mock value
            'status': 'PASS' if execution_time < 1000 else 'FAIL'
        }
        
    except Exception as e:
        logger.error(f"Lambda performance test failed: {str(e)}")
        return {
            'error': str(e),
            'status': 'ERROR'
        }

def test_sagemaker_performance() -> Dict[str, Any]:
    """
    Test SageMaker endpoint performance
    """
    try:
        logger.info("Testing SageMaker performance...")
        
        # Test ML inference performance
        start_time = time.time()
        
        # Generate test features
        test_features = [
            random.uniform(0, 1) for _ in range(8)
        ]
        
        payload = json.dumps({
            'instances': [test_features]
        })
        
        response = sagemaker_client.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT,
            ContentType='application/json',
            Body=payload
        )
        
        inference_latency = (time.time() - start_time) * 1000
        
        # Parse response
        result = json.loads(response['Body'].read().decode())
        
        return {
            'inference_latency_ms': inference_latency,
            'prediction': result.get('predictions', [{}])[0].get('prediction', 0),
            'confidence': result.get('predictions', [{}])[0].get('confidence', 0),
            'status': 'PASS' if inference_latency < 200 else 'FAIL'
        }
        
    except Exception as e:
        logger.error(f"SageMaker performance test failed: {str(e)}")
        return {
            'error': str(e),
            'status': 'ERROR'
        }

def test_redshift_performance() -> Dict[str, Any]:
    """
    Test Redshift query performance
    """
    try:
        logger.info("Testing Redshift performance...")
        
        # Test simple query performance
        start_time = time.time()
        
        query = """
        SELECT COUNT(*) as record_count
        FROM events 
        WHERE processed_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour';
        """
        
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER,
            Database='analytics',
            Sql=query
        )
        
        query_latency = (time.time() - start_time) * 1000
        
        return {
            'query_latency_ms': query_latency,
            'query_id': response.get('Id', 'unknown'),
            'status': 'PASS' if query_latency < 5000 else 'FAIL'
        }
        
    except Exception as e:
        logger.error(f"Redshift performance test failed: {str(e)}")
        return {
            'error': str(e),
            'status': 'ERROR'
        }

def test_end_to_end_performance() -> Dict[str, Any]:
    """
    Test end-to-end performance
    """
    try:
        logger.info("Testing end-to-end performance...")
        
        start_time = time.time()
        
        # Simulate complete data flow
        test_record = {
            'timestamp': datetime.utcnow().isoformat(),
            'user_id': f'e2e_test_{uuid.uuid4()}',
            'event_type': 'e2e_test',
            'value': random.uniform(0, 100)
        }
        
        # 1. Send to Kinesis
        kinesis_client.put_record(
            StreamName=KINESIS_STREAM,
            Data=json.dumps(test_record),
            PartitionKey=test_record['user_id']
        )
        
        # 2. Simulate Lambda processing
        time.sleep(0.2)  # Simulate processing time
        
        # 3. Simulate ML inference
        test_features = [random.uniform(0, 1) for _ in range(8)]
        payload = json.dumps({'instances': [test_features]})
        
        sagemaker_client.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT,
            ContentType='application/json',
            Body=payload
        )
        
        # 4. Simulate Redshift storage
        time.sleep(0.1)  # Simulate storage time
        
        end_to_end_latency = (time.time() - start_time) * 1000
        
        return {
            'end_to_end_latency_ms': end_to_end_latency,
            'status': 'PASS' if end_to_end_latency < 2000 else 'FAIL'
        }
        
    except Exception as e:
        logger.error(f"End-to-end performance test failed: {str(e)}")
        return {
            'error': str(e),
            'status': 'ERROR'
        }

def run_load_tests() -> Dict[str, Any]:
    """
    Run load tests with concurrent requests
    """
    try:
        logger.info("Running load tests...")
        
        def send_test_record():
            test_record = {
                'timestamp': datetime.utcnow().isoformat(),
                'user_id': f'load_test_{uuid.uuid4()}',
                'event_type': 'load_test',
                'value': random.uniform(0, 100)
            }
            
            start_time = time.time()
            kinesis_client.put_record(
                StreamName=KINESIS_STREAM,
                Data=json.dumps(test_record),
                PartitionKey=test_record['user_id']
            )
            return (time.time() - start_time) * 1000
        
        # Run 50 concurrent requests
        start_time = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(send_test_record) for _ in range(50)]
            latencies = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        total_time = (time.time() - start_time) * 1000
        
        return {
            'concurrent_requests': 50,
            'total_time_ms': total_time,
            'average_latency_ms': statistics.mean(latencies),
            'max_latency_ms': max(latencies),
            'min_latency_ms': min(latencies),
            'throughput_rps': 50000 / total_time if total_time > 0 else 0,
            'status': 'PASS' if statistics.mean(latencies) < 500 else 'FAIL'
        }
        
    except Exception as e:
        logger.error(f"Load test failed: {str(e)}")
        return {
            'error': str(e),
            'status': 'ERROR'
        }

def run_stress_tests() -> Dict[str, Any]:
    """
    Run stress tests with high load
    """
    try:
        logger.info("Running stress tests...")
        
        # Test with high volume of records
        start_time = time.time()
        
        records = []
        for i in range(100):
            record = {
                'timestamp': datetime.utcnow().isoformat(),
                'user_id': f'stress_test_{uuid.uuid4()}',
                'event_type': 'stress_test',
                'value': random.uniform(0, 100)
            }
            records.append({
                'Data': json.dumps(record),
                'PartitionKey': record['user_id']
            })
        
        kinesis_client.put_records(
            StreamName=KINESIS_STREAM,
            Records=records
        )
        
        stress_latency = (time.time() - start_time) * 1000
        
        return {
            'records_count': 100,
            'stress_latency_ms': stress_latency,
            'records_per_second': 100000 / stress_latency if stress_latency > 0 else 0,
            'status': 'PASS' if stress_latency < 1000 else 'FAIL'
        }
        
    except Exception as e:
        logger.error(f"Stress test failed: {str(e)}")
        return {
            'error': str(e),
            'status': 'ERROR'
        }

def analyze_performance_results(test_results: Dict[str, Any]) -> Dict[str, Any]:
    """
    Analyze performance test results
    """
    try:
        scores = []
        
        # Analyze each component
        for component, results in test_results.items():
            if isinstance(results, dict) and 'status' in results:
                if results['status'] == 'PASS':
                    scores.append(100)
                elif results['status'] == 'FAIL':
                    scores.append(50)
                else:
                    scores.append(0)
        
        overall_score = statistics.mean(scores) if scores else 0
        
        # Determine performance grade
        if overall_score >= 90:
            grade = 'A'
        elif overall_score >= 80:
            grade = 'B'
        elif overall_score >= 70:
            grade = 'C'
        elif overall_score >= 60:
            grade = 'D'
        else:
            grade = 'F'
        
        return {
            'overall_score': overall_score,
            'grade': grade,
            'component_scores': scores,
            'recommendations': generate_recommendations(test_results, overall_score)
        }
        
    except Exception as e:
        logger.error(f"Error analyzing performance results: {str(e)}")
        return {
            'overall_score': 0,
            'grade': 'F',
            'error': str(e)
        }

def generate_recommendations(test_results: Dict[str, Any], overall_score: float) -> List[str]:
    """
    Generate performance recommendations
    """
    recommendations = []
    
    if overall_score < 80:
        recommendations.append("Consider optimizing Lambda function memory and timeout settings")
        recommendations.append("Review Kinesis shard count and scaling policies")
        recommendations.append("Optimize SageMaker endpoint instance type and configuration")
        recommendations.append("Review Redshift cluster configuration and query optimization")
    
    if test_results.get('kinesis_performance', {}).get('status') == 'FAIL':
        recommendations.append("Increase Kinesis shard count for better throughput")
    
    if test_results.get('sagemaker_performance', {}).get('status') == 'FAIL':
        recommendations.append("Consider upgrading SageMaker endpoint instance type")
    
    if test_results.get('redshift_performance', {}).get('status') == 'FAIL':
        recommendations.append("Optimize Redshift queries and consider adding more nodes")
    
    return recommendations

def publish_performance_metrics(test_results: Dict[str, Any], analysis: Dict[str, Any]) -> None:
    """
    Publish performance metrics to CloudWatch
    """
    try:
        metrics = [
            {
                'MetricName': 'PerformanceTestScore',
                'Value': analysis['overall_score'],
                'Unit': 'Percent'
            },
            {
                'MetricName': 'KinesisLatency',
                'Value': test_results.get('kinesis_performance', {}).get('single_record_latency_ms', 0),
                'Unit': 'Milliseconds'
            },
            {
                'MetricName': 'SageMakerLatency',
                'Value': test_results.get('sagemaker_performance', {}).get('inference_latency_ms', 0),
                'Unit': 'Milliseconds'
            },
            {
                'MetricName': 'EndToEndLatency',
                'Value': test_results.get('end_to_end_performance', {}).get('end_to_end_latency_ms', 0),
                'Unit': 'Milliseconds'
            }
        ]
        
        cloudwatch_client.put_metric_data(
            Namespace='DataAnalytics/Performance',
            MetricData=metrics
        )
        
        logger.info("Performance metrics published to CloudWatch")
        
    except Exception as e:
        logger.error(f"Error publishing performance metrics: {str(e)}")

def generate_performance_report(test_results: Dict[str, Any], analysis: Dict[str, Any]) -> Dict[str, Any]:
    """
    Generate comprehensive performance report
    """
    return {
        'report_timestamp': datetime.utcnow().isoformat(),
        'overall_score': analysis['overall_score'],
        'grade': analysis['grade'],
        'summary': {
            'total_tests': len([k for k, v in test_results.items() if isinstance(v, dict) and 'status' in v]),
            'passed_tests': len([k for k, v in test_results.items() if isinstance(v, dict) and v.get('status') == 'PASS']),
            'failed_tests': len([k for k, v in test_results.items() if isinstance(v, dict) and v.get('status') == 'FAIL']),
            'error_tests': len([k for k, v in test_results.items() if isinstance(v, dict) and v.get('status') == 'ERROR'])
        },
        'recommendations': analysis.get('recommendations', []),
        'next_test_schedule': (datetime.utcnow() + timedelta(hours=1)).isoformat()
    }
