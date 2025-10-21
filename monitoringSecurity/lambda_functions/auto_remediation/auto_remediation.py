import json
import boto3
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ec2_client = boto3.client('ec2')
cloudwatch_client = boto3.client('cloudwatch')
sns_client = boto3.client('sns')
ssm_client = boto3.client('ssm')

def handler(event, context):
    """
    Auto-remediation Lambda function for CloudWatch alarms
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse the CloudWatch alarm event
        alarm_name = event['detail']['alarmName']
        alarm_state = event['detail']['state']['value']
        alarm_reason = event['detail']['state']['reason']
        
        logger.info(f"Processing alarm: {alarm_name}, State: {alarm_state}")
        
        # Get SNS topic ARN from environment
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        
        # Determine remediation action based on alarm name
        if 'high-cpu' in alarm_name.lower():
            result = handle_high_cpu_alarm(alarm_name, alarm_reason)
        elif 'high-memory' in alarm_name.lower():
            result = handle_high_memory_alarm(alarm_name, alarm_reason)
        elif 'disk-space' in alarm_name.lower():
            result = handle_disk_space_alarm(alarm_name, alarm_reason)
        elif 'instance-status' in alarm_name.lower():
            result = handle_instance_status_alarm(alarm_name, alarm_reason)
        else:
            result = handle_generic_alarm(alarm_name, alarm_reason)
        
        # Send notification
        if sns_topic_arn:
            send_notification(sns_topic_arn, alarm_name, alarm_state, result)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Auto-remediation completed',
                'alarm': alarm_name,
                'action': result
            })
        }
        
    except Exception as e:
        logger.error(f"Error in auto-remediation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def handle_high_cpu_alarm(alarm_name, alarm_reason):
    """Handle high CPU alarm"""
    logger.info("Handling high CPU alarm")
    
    # Extract instance ID from alarm name or reason
    instance_id = extract_instance_id(alarm_name, alarm_reason)
    
    if instance_id:
        # Check if instance is running
        response = ec2_client.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        
        if instance['State']['Name'] == 'running':
            # Try to restart the application service
            try:
                ssm_client.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="AWS-RunShellScript",
                    Parameters={
                        'commands': [
                            'sudo systemctl restart httpd',
                            'sudo systemctl status httpd'
                        ]
                    }
                )
                return f"Restarted Apache service on instance {instance_id}"
            except Exception as e:
                logger.error(f"Failed to restart service: {str(e)}")
                return f"Failed to restart service on instance {instance_id}: {str(e)}"
    
    return "High CPU alarm processed - manual intervention may be required"

def handle_high_memory_alarm(alarm_name, alarm_reason):
    """Handle high memory alarm"""
    logger.info("Handling high memory alarm")
    
    instance_id = extract_instance_id(alarm_name, alarm_reason)
    
    if instance_id:
        try:
            # Clear system cache
            ssm_client.send_command(
                InstanceIds=[instance_id],
                DocumentName="AWS-RunShellScript",
                Parameters={
                    'commands': [
                        'sudo sync',
                        'sudo echo 3 > /proc/sys/vm/drop_caches',
                        'free -h'
                    ]
                }
            )
            return f"Cleared system cache on instance {instance_id}"
        except Exception as e:
            logger.error(f"Failed to clear cache: {str(e)}")
            return f"Failed to clear cache on instance {instance_id}: {str(e)}"
    
    return "High memory alarm processed - manual intervention may be required"

def handle_disk_space_alarm(alarm_name, alarm_reason):
    """Handle disk space alarm"""
    logger.info("Handling disk space alarm")
    
    instance_id = extract_instance_id(alarm_name, alarm_reason)
    
    if instance_id:
        try:
            # Clean up log files and temporary files
            ssm_client.send_command(
                InstanceIds=[instance_id],
                DocumentName="AWS-RunShellScript",
                Parameters={
                    'commands': [
                        'sudo find /var/log -name "*.log" -type f -mtime +7 -delete',
                        'sudo find /tmp -type f -mtime +1 -delete',
                        'sudo yum clean all',
                        'df -h'
                    ]
                }
            )
            return f"Cleaned up disk space on instance {instance_id}"
        except Exception as e:
            logger.error(f"Failed to clean disk: {str(e)}")
            return f"Failed to clean disk on instance {instance_id}: {str(e)}"
    
    return "Disk space alarm processed - manual intervention may be required"

def handle_instance_status_alarm(alarm_name, alarm_reason):
    """Handle instance status alarm"""
    logger.info("Handling instance status alarm")
    
    instance_id = extract_instance_id(alarm_name, alarm_reason)
    
    if instance_id:
        try:
            # Reboot the instance
            ec2_client.reboot_instances(InstanceIds=[instance_id])
            return f"Rebooted instance {instance_id}"
        except Exception as e:
            logger.error(f"Failed to reboot instance: {str(e)}")
            return f"Failed to reboot instance {instance_id}: {str(e)}"
    
    return "Instance status alarm processed - manual intervention may be required"

def handle_generic_alarm(alarm_name, alarm_reason):
    """Handle generic alarm"""
    logger.info("Handling generic alarm")
    return f"Generic alarm processed: {alarm_name}"

def extract_instance_id(alarm_name, alarm_reason):
    """Extract instance ID from alarm name or reason"""
    import re
    
    # Try to extract from alarm name
    match = re.search(r'i-[a-f0-9]+', alarm_name)
    if match:
        return match.group(0)
    
    # Try to extract from reason
    match = re.search(r'i-[a-f0-9]+', alarm_reason)
    if match:
        return match.group(0)
    
    return None

def send_notification(sns_topic_arn, alarm_name, alarm_state, action_taken):
    """Send notification to SNS topic"""
    try:
        message = f"""
Auto-Remediation Alert

Alarm: {alarm_name}
State: {alarm_state}
Action Taken: {action_taken}
Timestamp: {datetime.now().isoformat()}

This is an automated response to a CloudWatch alarm.
        """
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=f"Auto-Remediation: {alarm_name}",
            Message=message
        )
        
        logger.info(f"Notification sent for alarm: {alarm_name}")
        
    except Exception as e:
        logger.error(f"Failed to send notification: {str(e)}")
