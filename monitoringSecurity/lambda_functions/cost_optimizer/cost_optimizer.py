import json
import boto3
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ec2_client = boto3.client('ec2')
cloudwatch_client = boto3.client('cloudwatch')
sns_client = boto3.client('sns')
ce_client = boto3.client('ce')  # Cost Explorer

def handler(event, context):
    """
    Cost optimization Lambda function
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Get SNS topic ARN from environment
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        
        # Perform cost optimization checks
        optimization_results = []
        
        # Check for idle instances
        idle_instances = check_idle_instances()
        if idle_instances:
            optimization_results.append(f"Found {len(idle_instances)} idle instances: {', '.join(idle_instances)}")
        
        # Check for oversized instances
        oversized_instances = check_oversized_instances()
        if oversized_instances:
            optimization_results.append(f"Found {len(oversized_instances)} oversized instances: {', '.join(oversized_instances)}")
        
        # Check for unused EBS volumes
        unused_volumes = check_unused_volumes()
        if unused_volumes:
            optimization_results.append(f"Found {len(unused_volumes)} unused EBS volumes: {', '.join(unused_volumes)}")
        
        # Check for unused Elastic IPs
        unused_eips = check_unused_elastic_ips()
        if unused_eips:
            optimization_results.append(f"Found {len(unused_eips)} unused Elastic IPs: {', '.join(unused_eips)}")
        
        # Get cost analysis
        cost_analysis = get_cost_analysis()
        
        # Send notification if optimizations are found
        if optimization_results or cost_analysis:
            if sns_topic_arn:
                send_cost_optimization_notification(sns_topic_arn, optimization_results, cost_analysis)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cost optimization analysis completed',
                'optimizations': optimization_results,
                'cost_analysis': cost_analysis
            })
        }
        
    except Exception as e:
        logger.error(f"Error in cost optimization: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def check_idle_instances():
    """Check for idle EC2 instances"""
    logger.info("Checking for idle instances")
    
    idle_instances = []
    
    try:
        # Get all running instances
        response = ec2_client.describe_instances(
            Filters=[
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                instance_type = instance['InstanceType']
                
                # Check CPU utilization for the last 7 days
                if is_instance_idle(instance_id):
                    idle_instances.append(instance_id)
                    logger.info(f"Instance {instance_id} ({instance_type}) appears to be idle")
        
    except Exception as e:
        logger.error(f"Failed to check idle instances: {str(e)}")
    
    return idle_instances

def is_instance_idle(instance_id):
    """Check if an instance is idle based on CPU utilization"""
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=7)
        
        response = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='CPUUtilization',
            Dimensions=[
                {'Name': 'InstanceId', 'Value': instance_id}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,  # 1 hour
            Statistics=['Average']
        )
        
        if not response['Datapoints']:
            return False
        
        # Calculate average CPU utilization
        total_cpu = sum(point['Average'] for point in response['Datapoints'])
        avg_cpu = total_cpu / len(response['Datapoints'])
        
        # Consider idle if average CPU is less than 5%
        return avg_cpu < 5.0
        
    except Exception as e:
        logger.error(f"Failed to check CPU utilization for instance {instance_id}: {str(e)}")
        return False

def check_oversized_instances():
    """Check for oversized instances"""
    logger.info("Checking for oversized instances")
    
    oversized_instances = []
    
    try:
        # Get all running instances
        response = ec2_client.describe_instances(
            Filters=[
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                instance_type = instance['InstanceType']
                
                # Check if instance is oversized based on CPU and memory utilization
                if is_instance_oversized(instance_id, instance_type):
                    oversized_instances.append(instance_id)
                    logger.info(f"Instance {instance_id} ({instance_type}) appears to be oversized")
        
    except Exception as e:
        logger.error(f"Failed to check oversized instances: {str(e)}")
    
    return oversized_instances

def is_instance_oversized(instance_id, instance_type):
    """Check if an instance is oversized"""
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=7)
        
        # Check CPU utilization
        cpu_response = cloudwatch_client.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='CPUUtilization',
            Dimensions=[
                {'Name': 'InstanceId', 'Value': instance_id}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average']
        )
        
        if not cpu_response['Datapoints']:
            return False
        
        # Calculate average CPU utilization
        total_cpu = sum(point['Average'] for point in cpu_response['Datapoints'])
        avg_cpu = total_cpu / len(cpu_response['Datapoints'])
        
        # Check memory utilization (if available)
        try:
            memory_response = cloudwatch_client.get_metric_statistics(
                Namespace='System/Linux',
                MetricName='MemoryUtilization',
                Dimensions=[
                    {'Name': 'InstanceId', 'Value': instance_id}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=3600,
                Statistics=['Average']
            )
            
            if memory_response['Datapoints']:
                total_memory = sum(point['Average'] for point in memory_response['Datapoints'])
                avg_memory = total_memory / len(memory_response['Datapoints'])
            else:
                avg_memory = 0
        except:
            avg_memory = 0
        
        # Consider oversized if both CPU and memory are consistently low
        return avg_cpu < 20.0 and avg_memory < 30.0
        
    except Exception as e:
        logger.error(f"Failed to check if instance {instance_id} is oversized: {str(e)}")
        return False

def check_unused_volumes():
    """Check for unused EBS volumes"""
    logger.info("Checking for unused EBS volumes")
    
    unused_volumes = []
    
    try:
        # Get all available volumes
        response = ec2_client.describe_volumes(
            Filters=[
                {'Name': 'status', 'Values': ['available']}
            ]
        )
        
        for volume in response['Volumes']:
            volume_id = volume['VolumeId']
            size = volume['Size']
            volume_type = volume['VolumeType']
            
            # Check if volume has been unattached for more than 7 days
            if is_volume_unused(volume_id):
                unused_volumes.append(volume_id)
                logger.info(f"Volume {volume_id} ({size}GB {volume_type}) appears to be unused")
        
    except Exception as e:
        logger.error(f"Failed to check unused volumes: {str(e)}")
    
    return unused_volumes

def is_volume_unused(volume_id):
    """Check if a volume has been unused for a long time"""
    try:
        # Get volume details
        response = ec2_client.describe_volumes(VolumeIds=[volume_id])
        volume = response['Volumes'][0]
        
        # Check if volume is available (not attached)
        if volume['State'] == 'available':
            # Check creation time
            create_time = volume['CreateTime']
            days_since_creation = (datetime.now(create_time.tzinfo) - create_time).days
            
            # Consider unused if created more than 7 days ago and still available
            return days_since_creation > 7
        
        return False
        
    except Exception as e:
        logger.error(f"Failed to check if volume {volume_id} is unused: {str(e)}")
        return False

def check_unused_elastic_ips():
    """Check for unused Elastic IPs"""
    logger.info("Checking for unused Elastic IPs")
    
    unused_eips = []
    
    try:
        # Get all Elastic IPs
        response = ec2_client.describe_addresses()
        
        for address in response['Addresses']:
            allocation_id = address['AllocationId']
            public_ip = address['PublicIp']
            
            # Check if Elastic IP is not associated with any instance
            if 'InstanceId' not in address:
                unused_eips.append(allocation_id)
                logger.info(f"Elastic IP {public_ip} ({allocation_id}) is not associated with any instance")
        
    except Exception as e:
        logger.error(f"Failed to check unused Elastic IPs: {str(e)}")
    
    return unused_eips

def get_cost_analysis():
    """Get cost analysis for the current month"""
    logger.info("Getting cost analysis")
    
    try:
        # Get current month's costs
        end_date = datetime.utcnow().date()
        start_date = end_date.replace(day=1)
        
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Granularity='MONTHLY',
            Metrics=['BlendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'SERVICE'}
            ]
        )
        
        cost_analysis = {}
        
        for result in response['ResultsByTime']:
            for group in result['Groups']:
                service = group['Keys'][0]
                cost = float(group['Metrics']['BlendedCost']['Amount'])
                cost_analysis[service] = cost
        
        return cost_analysis
        
    except Exception as e:
        logger.error(f"Failed to get cost analysis: {str(e)}")
        return {}

def send_cost_optimization_notification(sns_topic_arn, optimizations, cost_analysis):
    """Send cost optimization notification to SNS topic"""
    try:
        message = f"""
Cost Optimization Report

Optimization Opportunities:
{chr(10).join(f"- {opt}" for opt in optimizations) if optimizations else "No optimization opportunities found"}

Cost Analysis (Current Month):
{chr(10).join(f"- {service}: ${cost:.2f}" for service, cost in cost_analysis.items()) if cost_analysis else "Cost analysis not available"}

Timestamp: {datetime.now().isoformat()}

This is an automated cost optimization report.
        """
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject="Cost Optimization Report",
            Message=message
        )
        
        logger.info("Cost optimization notification sent")
        
    except Exception as e:
        logger.error(f"Failed to send cost optimization notification: {str(e)}")
