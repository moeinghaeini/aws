"""
Cost Optimization Lambda Function
Automated cost optimization and resource right-sizing for the analytics platform
"""

import json
import boto3
import logging
import datetime
from typing import Dict, List, Any, Optional
import os
from decimal import Decimal

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ce_client = boto3.client('ce')  # Cost Explorer
kinesis_client = boto3.client('kinesis')
redshift_client = boto3.client('redshift')
sagemaker_client = boto3.client('sagemaker')
lambda_client = boto3.client('lambda')
cloudwatch_client = boto3.client('cloudwatch')

# Environment variables
KINESIS_STREAM = os.environ.get('KINESIS_STREAM')
REDSHIFT_CLUSTER = os.environ.get('REDSHIFT_CLUSTER')
SAGEMAKER_ENDPOINT = os.environ.get('SAGEMAKER_ENDPOINT')
S3_BUCKET = os.environ.get('S3_BUCKET')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for cost optimization
    """
    try:
        logger.info("Starting cost optimization analysis...")
        
        # Get current costs
        current_costs = get_current_costs()
        
        # Analyze resource utilization
        utilization_analysis = analyze_resource_utilization()
        
        # Generate optimization recommendations
        recommendations = generate_optimization_recommendations(current_costs, utilization_analysis)
        
        # Apply automatic optimizations
        applied_optimizations = apply_automatic_optimizations(recommendations)
        
        # Calculate potential savings
        potential_savings = calculate_potential_savings(recommendations)
        
        # Generate cost optimization report
        report = generate_cost_optimization_report(
            current_costs, 
            utilization_analysis, 
            recommendations, 
            applied_optimizations, 
            potential_savings
        )
        
        # Publish metrics to CloudWatch
        publish_cost_optimization_metrics(current_costs, potential_savings)
        
        logger.info(f"Cost optimization completed. Potential savings: ${potential_savings['total_savings']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cost optimization analysis completed successfully',
                'current_costs': current_costs,
                'potential_savings': potential_savings,
                'recommendations': recommendations,
                'applied_optimizations': applied_optimizations,
                'report': report
            })
        }
        
    except Exception as e:
        logger.error(f"Error in cost optimization: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Cost optimization failed'
            })
        }

def get_current_costs() -> Dict[str, Any]:
    """
    Get current costs for all services
    """
    try:
        # Get costs for the last 30 days
        end_date = datetime.date.today()
        start_date = end_date - datetime.timedelta(days=30)
        
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Granularity='MONTHLY',
            Metrics=['BlendedCost'],
            GroupBy=[
                {
                    'Type': 'DIMENSION',
                    'Key': 'SERVICE'
                }
            ]
        )
        
        costs = {}
        for result in response['ResultsByTime']:
            for group in result['Groups']:
                service = group['Keys'][0]
                cost = float(group['Metrics']['BlendedCost']['Amount'])
                costs[service] = cost
        
        return {
            'total_cost': sum(costs.values()),
            'service_costs': costs,
            'period': f"{start_date} to {end_date}"
        }
        
    except Exception as e:
        logger.error(f"Error getting current costs: {str(e)}")
        return {
            'total_cost': 0,
            'service_costs': {},
            'error': str(e)
        }

def analyze_resource_utilization() -> Dict[str, Any]:
    """
    Analyze resource utilization across all services
    """
    try:
        utilization = {}
        
        # Analyze Kinesis utilization
        utilization['kinesis'] = analyze_kinesis_utilization()
        
        # Analyze Redshift utilization
        utilization['redshift'] = analyze_redshift_utilization()
        
        # Analyze SageMaker utilization
        utilization['sagemaker'] = analyze_sagemaker_utilization()
        
        # Analyze Lambda utilization
        utilization['lambda'] = analyze_lambda_utilization()
        
        # Analyze S3 utilization
        utilization['s3'] = analyze_s3_utilization()
        
        return utilization
        
    except Exception as e:
        logger.error(f"Error analyzing resource utilization: {str(e)}")
        return {}

def analyze_kinesis_utilization() -> Dict[str, Any]:
    """
    Analyze Kinesis stream utilization
    """
    try:
        # Get stream description
        response = kinesis_client.describe_stream(StreamName=KINESIS_STREAM)
        stream_info = response['StreamDescription']
        
        # Get metrics for the last 7 days
        end_time = datetime.datetime.utcnow()
        start_time = end_time - datetime.timedelta(days=7)
        
        metrics = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/Kinesis',
            MetricName='IncomingRecords',
            Dimensions=[
                {
                    'Name': 'StreamName',
                    'Value': KINESIS_STREAM
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,  # 1 hour
            Statistics=['Average', 'Maximum']
        )
        
        if metrics['Datapoints']:
            avg_records = sum(point['Average'] for point in metrics['Datapoints']) / len(metrics['Datapoints'])
            max_records = max(point['Maximum'] for point in metrics['Datapoints'])
        else:
            avg_records = 0
            max_records = 0
        
        shard_count = len(stream_info['Shards'])
        records_per_shard = avg_records / shard_count if shard_count > 0 else 0
        
        # Kinesis can handle up to 1000 records per second per shard
        utilization_percentage = (records_per_shard / 1000) * 100
        
        return {
            'shard_count': shard_count,
            'avg_records_per_second': avg_records,
            'max_records_per_second': max_records,
            'records_per_shard': records_per_shard,
            'utilization_percentage': utilization_percentage,
            'recommendation': 'scale_down' if utilization_percentage < 30 else 'scale_up' if utilization_percentage > 80 else 'maintain'
        }
        
    except Exception as e:
        logger.error(f"Error analyzing Kinesis utilization: {str(e)}")
        return {'error': str(e)}

def analyze_redshift_utilization() -> Dict[str, Any]:
    """
    Analyze Redshift cluster utilization
    """
    try:
        # Get cluster description
        response = redshift_client.describe_clusters(ClusterIdentifier=REDSHIFT_CLUSTER)
        cluster = response['Clusters'][0]
        
        # Get CPU utilization metrics
        end_time = datetime.datetime.utcnow()
        start_time = end_time - datetime.timedelta(days=7)
        
        cpu_metrics = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/Redshift',
            MetricName='CPUUtilization',
            Dimensions=[
                {
                    'Name': 'ClusterIdentifier',
                    'Value': REDSHIFT_CLUSTER
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average', 'Maximum']
        )
        
        if cpu_metrics['Datapoints']:
            avg_cpu = sum(point['Average'] for point in cpu_metrics['Datapoints']) / len(cpu_metrics['Datapoints'])
            max_cpu = max(point['Maximum'] for point in cpu_metrics['Datapoints'])
        else:
            avg_cpu = 0
            max_cpu = 0
        
        node_type = cluster['NodeType']
        node_count = cluster['NumberOfNodes']
        
        return {
            'node_type': node_type,
            'node_count': node_count,
            'avg_cpu_utilization': avg_cpu,
            'max_cpu_utilization': max_cpu,
            'recommendation': 'scale_down' if avg_cpu < 30 else 'scale_up' if avg_cpu > 80 else 'maintain'
        }
        
    except Exception as e:
        logger.error(f"Error analyzing Redshift utilization: {str(e)}")
        return {'error': str(e)}

def analyze_sagemaker_utilization() -> Dict[str, Any]:
    """
    Analyze SageMaker endpoint utilization
    """
    try:
        # Get endpoint description
        response = sagemaker_client.describe_endpoint(EndpointName=SAGEMAKER_ENDPOINT)
        endpoint = response['EndpointConfigName']
        
        # Get endpoint config
        config_response = sagemaker_client.describe_endpoint_config(EndpointConfigName=endpoint)
        config = config_response['ProductionVariants'][0]
        
        # Get invocation metrics
        end_time = datetime.datetime.utcnow()
        start_time = end_time - datetime.timedelta(days=7)
        
        invocation_metrics = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/SageMaker',
            MetricName='Invocations',
            Dimensions=[
                {
                    'Name': 'EndpointName',
                    'Value': SAGEMAKER_ENDPOINT
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Sum']
        )
        
        if invocation_metrics['Datapoints']:
            total_invocations = sum(point['Sum'] for point in invocation_metrics['Datapoints'])
            avg_invocations_per_hour = total_invocations / len(invocation_metrics['Datapoints'])
        else:
            total_invocations = 0
            avg_invocations_per_hour = 0
        
        instance_type = config['InstanceType']
        instance_count = config['InitialInstanceCount']
        
        return {
            'instance_type': instance_type,
            'instance_count': instance_count,
            'total_invocations': total_invocations,
            'avg_invocations_per_hour': avg_invocations_per_hour,
            'recommendation': 'scale_down' if avg_invocations_per_hour < 10 else 'scale_up' if avg_invocations_per_hour > 100 else 'maintain'
        }
        
    except Exception as e:
        logger.error(f"Error analyzing SageMaker utilization: {str(e)}")
        return {'error': str(e)}

def analyze_lambda_utilization() -> Dict[str, Any]:
    """
    Analyze Lambda function utilization
    """
    try:
        # Get function configuration
        response = lambda_client.get_function(FunctionName='data-analytics-ml-analytics-data-processor')
        config = response['Configuration']
        
        # Get invocation metrics
        end_time = datetime.datetime.utcnow()
        start_time = end_time - datetime.timedelta(days=7)
        
        invocation_metrics = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Invocations',
            Dimensions=[
                {
                    'Name': 'FunctionName',
                    'Value': 'data-analytics-ml-analytics-data-processor'
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Sum']
        )
        
        if invocation_metrics['Datapoints']:
            total_invocations = sum(point['Sum'] for point in invocation_metrics['Datapoints'])
            avg_invocations_per_hour = total_invocations / len(invocation_metrics['Datapoints'])
        else:
            total_invocations = 0
            avg_invocations_per_hour = 0
        
        memory_size = config['MemorySize']
        timeout = config['Timeout']
        
        return {
            'memory_size': memory_size,
            'timeout': timeout,
            'total_invocations': total_invocations,
            'avg_invocations_per_hour': avg_invocations_per_hour,
            'recommendation': 'optimize_memory' if memory_size > 512 else 'maintain'
        }
        
    except Exception as e:
        logger.error(f"Error analyzing Lambda utilization: {str(e)}")
        return {'error': str(e)}

def analyze_s3_utilization() -> Dict[str, Any]:
    """
    Analyze S3 bucket utilization
    """
    try:
        # Get bucket size and object count
        response = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/S3',
            MetricName='BucketSizeBytes',
            Dimensions=[
                {
                    'Name': 'BucketName',
                    'Value': S3_BUCKET
                },
                {
                    'Name': 'StorageType',
                    'Value': 'StandardStorage'
                }
            ],
            StartTime=datetime.datetime.utcnow() - datetime.timedelta(days=1),
            EndTime=datetime.datetime.utcnow(),
            Period=86400,
            Statistics=['Average']
        )
        
        if response['Datapoints']:
            bucket_size_bytes = response['Datapoints'][0]['Average']
            bucket_size_gb = bucket_size_bytes / (1024**3)
        else:
            bucket_size_gb = 0
        
        return {
            'bucket_size_gb': bucket_size_gb,
            'recommendation': 'enable_lifecycle' if bucket_size_gb > 100 else 'maintain'
        }
        
    except Exception as e:
        logger.error(f"Error analyzing S3 utilization: {str(e)}")
        return {'error': str(e)}

def generate_optimization_recommendations(current_costs: Dict[str, Any], utilization: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Generate cost optimization recommendations
    """
    recommendations = []
    
    # Kinesis recommendations
    if 'kinesis' in utilization and 'recommendation' in utilization['kinesis']:
        kinesis_rec = utilization['kinesis']['recommendation']
        if kinesis_rec == 'scale_down':
            recommendations.append({
                'service': 'kinesis',
                'action': 'scale_down_shards',
                'current_shards': utilization['kinesis']['shard_count'],
                'recommended_shards': max(1, utilization['kinesis']['shard_count'] - 1),
                'potential_savings': 25.0,  # $25 per shard per month
                'risk_level': 'low'
            })
        elif kinesis_rec == 'scale_up':
            recommendations.append({
                'service': 'kinesis',
                'action': 'scale_up_shards',
                'current_shards': utilization['kinesis']['shard_count'],
                'recommended_shards': utilization['kinesis']['shard_count'] + 1,
                'potential_savings': -25.0,  # Cost increase
                'risk_level': 'low'
            })
    
    # Redshift recommendations
    if 'redshift' in utilization and 'recommendation' in utilization['redshift']:
        redshift_rec = utilization['redshift']['recommendation']
        if redshift_rec == 'scale_down':
            recommendations.append({
                'service': 'redshift',
                'action': 'scale_down_nodes',
                'current_nodes': utilization['redshift']['node_count'],
                'recommended_nodes': max(1, utilization['redshift']['node_count'] - 1),
                'potential_savings': 150.0,  # $150 per node per month
                'risk_level': 'medium'
            })
    
    # SageMaker recommendations
    if 'sagemaker' in utilization and 'recommendation' in utilization['sagemaker']:
        sagemaker_rec = utilization['sagemaker']['recommendation']
        if sagemaker_rec == 'scale_down':
            recommendations.append({
                'service': 'sagemaker',
                'action': 'scale_down_instances',
                'current_instances': utilization['sagemaker']['instance_count'],
                'recommended_instances': max(1, utilization['sagemaker']['instance_count'] - 1),
                'potential_savings': 50.0,  # $50 per instance per month
                'risk_level': 'medium'
            })
    
    # Lambda recommendations
    if 'lambda' in utilization and 'recommendation' in utilization['lambda']:
        lambda_rec = utilization['lambda']['recommendation']
        if lambda_rec == 'optimize_memory':
            recommendations.append({
                'service': 'lambda',
                'action': 'optimize_memory',
                'current_memory': utilization['lambda']['memory_size'],
                'recommended_memory': 256,  # Reduce to 256MB
                'potential_savings': 10.0,  # $10 per month
                'risk_level': 'low'
            })
    
    # S3 recommendations
    if 's3' in utilization and 'recommendation' in utilization['s3']:
        s3_rec = utilization['s3']['recommendation']
        if s3_rec == 'enable_lifecycle':
            recommendations.append({
                'service': 's3',
                'action': 'enable_lifecycle_policies',
                'current_size_gb': utilization['s3']['bucket_size_gb'],
                'potential_savings': utilization['s3']['bucket_size_gb'] * 0.02,  # 2 cents per GB per month
                'risk_level': 'low'
            })
    
    return recommendations

def apply_automatic_optimizations(recommendations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Apply automatic optimizations for low-risk recommendations
    """
    applied = []
    
    for rec in recommendations:
        if rec['risk_level'] == 'low':
            try:
                if rec['service'] == 'lambda' and rec['action'] == 'optimize_memory':
                    # Apply Lambda memory optimization
                    lambda_client.update_function_configuration(
                        FunctionName='data-analytics-ml-analytics-data-processor',
                        MemorySize=rec['recommended_memory']
                    )
                    applied.append({
                        'recommendation': rec,
                        'status': 'applied',
                        'timestamp': datetime.datetime.utcnow().isoformat()
                    })
                    logger.info(f"Applied Lambda memory optimization: {rec['recommended_memory']}MB")
                
                elif rec['service'] == 'kinesis' and rec['action'] == 'scale_down_shards':
                    # Apply Kinesis shard scaling
                    kinesis_client.update_shard_count(
                        StreamName=KINESIS_STREAM,
                        TargetShardCount=rec['recommended_shards'],
                        ScalingType='UNIFORM_SCALING'
                    )
                    applied.append({
                        'recommendation': rec,
                        'status': 'applied',
                        'timestamp': datetime.datetime.utcnow().isoformat()
                    })
                    logger.info(f"Applied Kinesis shard scaling: {rec['recommended_shards']} shards")
                
            except Exception as e:
                logger.error(f"Failed to apply optimization {rec['action']}: {str(e)}")
                applied.append({
                    'recommendation': rec,
                    'status': 'failed',
                    'error': str(e),
                    'timestamp': datetime.datetime.utcnow().isoformat()
                })
    
    return applied

def calculate_potential_savings(recommendations: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Calculate potential cost savings from recommendations
    """
    total_savings = 0
    monthly_savings = 0
    annual_savings = 0
    
    for rec in recommendations:
        savings = rec.get('potential_savings', 0)
        if savings > 0:
            total_savings += savings
            monthly_savings += savings
            annual_savings += savings * 12
    
    return {
        'total_savings': total_savings,
        'monthly_savings': monthly_savings,
        'annual_savings': annual_savings,
        'savings_percentage': (total_savings / 1000) * 100 if total_savings > 0 else 0  # Assuming $1000 baseline
    }

def generate_cost_optimization_report(current_costs: Dict[str, Any], utilization: Dict[str, Any], 
                                    recommendations: List[Dict[str, Any]], applied: List[Dict[str, Any]], 
                                    savings: Dict[str, Any]) -> Dict[str, Any]:
    """
    Generate comprehensive cost optimization report
    """
    return {
        'report_timestamp': datetime.datetime.utcnow().isoformat(),
        'current_costs': current_costs,
        'resource_utilization': utilization,
        'recommendations': recommendations,
        'applied_optimizations': applied,
        'potential_savings': savings,
        'summary': {
            'total_recommendations': len(recommendations),
            'applied_optimizations': len([a for a in applied if a['status'] == 'applied']),
            'failed_optimizations': len([a for a in applied if a['status'] == 'failed']),
            'pending_optimizations': len([r for r in recommendations if r['risk_level'] != 'low'])
        },
        'next_optimization_schedule': (datetime.datetime.utcnow() + datetime.timedelta(days=1)).isoformat()
    }

def publish_cost_optimization_metrics(current_costs: Dict[str, Any], savings: Dict[str, Any]) -> None:
    """
    Publish cost optimization metrics to CloudWatch
    """
    try:
        metrics = [
            {
                'MetricName': 'CurrentMonthlyCost',
                'Value': current_costs.get('total_cost', 0),
                'Unit': 'None'
            },
            {
                'MetricName': 'PotentialMonthlySavings',
                'Value': savings.get('monthly_savings', 0),
                'Unit': 'None'
            },
            {
                'MetricName': 'SavingsPercentage',
                'Value': savings.get('savings_percentage', 0),
                'Unit': 'Percent'
            }
        ]
        
        cloudwatch_client.put_metric_data(
            Namespace='DataAnalytics/CostOptimization',
            MetricData=metrics
        )
        
        logger.info("Cost optimization metrics published to CloudWatch")
        
    except Exception as e:
        logger.error(f"Error publishing cost optimization metrics: {str(e)}")
