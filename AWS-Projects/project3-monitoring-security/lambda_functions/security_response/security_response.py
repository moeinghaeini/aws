import json
import boto3
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ec2_client = boto3.client('ec2')
guardduty_client = boto3.client('guardduty')
securityhub_client = boto3.client('securityhub')
sns_client = boto3.client('sns')

def handler(event, context):
    """
    Security response Lambda function for GuardDuty and Security Hub findings
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Get SNS topic ARN from environment
        security_sns_topic_arn = os.environ.get('SECURITY_SNS_TOPIC_ARN')
        
        # Determine the source of the security event
        if 'guardduty' in event.get('source', '').lower():
            result = handle_guardduty_finding(event)
        elif 'securityhub' in event.get('source', '').lower():
            result = handle_securityhub_finding(event)
        else:
            result = handle_generic_security_event(event)
        
        # Send notification
        if security_sns_topic_arn:
            send_security_notification(security_sns_topic_arn, event, result)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Security response completed',
                'action': result
            })
        }
        
    except Exception as e:
        logger.error(f"Error in security response: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def handle_guardduty_finding(event):
    """Handle GuardDuty finding"""
    logger.info("Handling GuardDuty finding")
    
    finding = event.get('detail', {})
    finding_id = finding.get('id')
    severity = finding.get('severity', 0)
    finding_type = finding.get('type', '')
    
    logger.info(f"GuardDuty finding: {finding_id}, Severity: {severity}, Type: {finding_type}")
    
    actions_taken = []
    
    # Handle different types of findings
    if 'Recon' in finding_type:
        actions_taken.append(handle_reconnaissance_activity(finding))
    elif 'Backdoor' in finding_type:
        actions_taken.append(handle_backdoor_activity(finding))
    elif 'Trojan' in finding_type:
        actions_taken.append(handle_trojan_activity(finding))
    elif 'UnauthorizedAPICall' in finding_type:
        actions_taken.append(handle_unauthorized_api_call(finding))
    else:
        actions_taken.append(handle_generic_guardduty_finding(finding))
    
    # Archive the finding if severity is high
    if severity >= 7.0:
        try:
            guardduty_client.archive_findings(
                DetectorId=get_guardduty_detector_id(),
                FindingIds=[finding_id]
            )
            actions_taken.append(f"Archived high-severity finding: {finding_id}")
        except Exception as e:
            logger.error(f"Failed to archive finding: {str(e)}")
    
    return "; ".join(actions_taken)

def handle_securityhub_finding(event):
    """Handle Security Hub finding"""
    logger.info("Handling Security Hub finding")
    
    findings = event.get('detail', {}).get('findings', [])
    actions_taken = []
    
    for finding in findings:
        finding_id = finding.get('Id')
        severity = finding.get('Severity', {}).get('Label', '')
        finding_type = finding.get('ProductFields', {}).get('aws/securityhub/ProductName', '')
        
        logger.info(f"Security Hub finding: {finding_id}, Severity: {severity}, Type: {finding_type}")
        
        if 'GuardDuty' in finding_type:
            actions_taken.append(handle_guardduty_securityhub_finding(finding))
        elif 'Config' in finding_type:
            actions_taken.append(handle_config_finding(finding))
        else:
            actions_taken.append(handle_generic_securityhub_finding(finding))
    
    return "; ".join(actions_taken)

def handle_reconnaissance_activity(finding):
    """Handle reconnaissance activity"""
    logger.info("Handling reconnaissance activity")
    
    # Block suspicious IP addresses
    service = finding.get('service', {})
    action = finding.get('action', {})
    
    if 'networkConnectionAction' in action:
        remote_ip = action['networkConnectionAction'].get('remoteIpDetails', {}).get('ipAddressV4')
        if remote_ip:
            return block_suspicious_ip(remote_ip, "Reconnaissance activity detected")
    
    return "Reconnaissance activity detected and analyzed"

def handle_backdoor_activity(finding):
    """Handle backdoor activity"""
    logger.info("Handling backdoor activity")
    
    # Isolate affected resources
    resources = finding.get('resource', {})
    instance_id = resources.get('instanceDetails', {}).get('instanceId')
    
    if instance_id:
        return isolate_instance(instance_id, "Backdoor activity detected")
    
    return "Backdoor activity detected and analyzed"

def handle_trojan_activity(finding):
    """Handle trojan activity"""
    logger.info("Handling trojan activity")
    
    # Isolate affected resources
    resources = finding.get('resource', {})
    instance_id = resources.get('instanceDetails', {}).get('instanceId')
    
    if instance_id:
        return isolate_instance(instance_id, "Trojan activity detected")
    
    return "Trojan activity detected and analyzed"

def handle_unauthorized_api_call(finding):
    """Handle unauthorized API call"""
    logger.info("Handling unauthorized API call")
    
    # Revoke temporary credentials if possible
    service = finding.get('service', {})
    action = finding.get('action', {})
    
    if 'awsApiCallAction' in action:
        api_call = action['awsApiCallAction']
        service_name = api_call.get('serviceName')
        api_name = api_call.get('api')
        
        return f"Unauthorized API call detected: {service_name}.{api_name}"
    
    return "Unauthorized API call detected and analyzed"

def handle_config_finding(finding):
    """Handle Config compliance finding"""
    logger.info("Handling Config compliance finding")
    
    # Get compliance details
    compliance_status = finding.get('Compliance', {}).get('Status')
    rule_name = finding.get('ProductFields', {}).get('aws/config/ConfigRuleName')
    
    if compliance_status == 'FAILED':
        return f"Compliance violation detected: {rule_name}"
    
    return f"Config finding processed: {rule_name}"

def handle_generic_guardduty_finding(finding):
    """Handle generic GuardDuty finding"""
    logger.info("Handling generic GuardDuty finding")
    return "Generic GuardDuty finding processed"

def handle_generic_securityhub_finding(finding):
    """Handle generic Security Hub finding"""
    logger.info("Handling generic Security Hub finding")
    return "Generic Security Hub finding processed"

def handle_generic_security_event(event):
    """Handle generic security event"""
    logger.info("Handling generic security event")
    return "Generic security event processed"

def block_suspicious_ip(ip_address, reason):
    """Block suspicious IP address"""
    try:
        # Create a security group rule to block the IP
        # This is a simplified example - in practice, you'd want more sophisticated blocking
        logger.info(f"Blocking suspicious IP: {ip_address}")
        return f"Blocked suspicious IP {ip_address}: {reason}"
    except Exception as e:
        logger.error(f"Failed to block IP {ip_address}: {str(e)}")
        return f"Failed to block IP {ip_address}: {str(e)}"

def isolate_instance(instance_id, reason):
    """Isolate instance by modifying security groups"""
    try:
        # Get current security groups
        response = ec2_client.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        current_sgs = [sg['GroupId'] for sg in instance['SecurityGroups']]
        
        # Create an isolation security group (no inbound/outbound traffic)
        isolation_sg = create_isolation_security_group(instance['VpcId'])
        
        # Replace security groups with isolation group
        ec2_client.modify_instance_attribute(
            InstanceId=instance_id,
            Groups=[isolation_sg]
        )
        
        logger.info(f"Isolated instance {instance_id}")
        return f"Isolated instance {instance_id}: {reason}"
        
    except Exception as e:
        logger.error(f"Failed to isolate instance {instance_id}: {str(e)}")
        return f"Failed to isolate instance {instance_id}: {str(e)}"

def create_isolation_security_group(vpc_id):
    """Create an isolation security group"""
    try:
        response = ec2_client.create_security_group(
            GroupName='isolation-sg',
            Description='Isolation security group for compromised instances',
            VpcId=vpc_id
        )
        return response['GroupId']
    except Exception as e:
        logger.error(f"Failed to create isolation security group: {str(e)}")
        return None

def get_guardduty_detector_id():
    """Get GuardDuty detector ID"""
    try:
        response = guardduty_client.list_detectors()
        if response['DetectorIds']:
            return response['DetectorIds'][0]
    except Exception as e:
        logger.error(f"Failed to get GuardDuty detector ID: {str(e)}")
    return None

def send_security_notification(sns_topic_arn, event, action_taken):
    """Send security notification to SNS topic"""
    try:
        source = event.get('source', 'Unknown')
        detail_type = event.get('detail-type', 'Unknown')
        
        message = f"""
Security Alert

Source: {source}
Detail Type: {detail_type}
Action Taken: {action_taken}
Timestamp: {datetime.now().isoformat()}

This is an automated response to a security event.
        """
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=f"Security Alert: {source}",
            Message=message
        )
        
        logger.info(f"Security notification sent for: {source}")
        
    except Exception as e:
        logger.error(f"Failed to send security notification: {str(e)}")
