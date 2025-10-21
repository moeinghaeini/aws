import json
import boto3
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
config_client = boto3.client('config')
sns_client = boto3.client('sns')
ec2_client = boto3.client('ec2')

def handler(event, context):
    """
    Compliance monitoring Lambda function for AWS Config
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Get SNS topic ARN from environment
        compliance_sns_topic_arn = os.environ.get('COMPLIANCE_SNS_TOPIC_ARN')
        
        # Parse the Config compliance event
        detail = event.get('detail', {})
        config_rule_name = detail.get('configRuleName')
        compliance_type = detail.get('newEvaluationResult', {}).get('complianceType')
        
        logger.info(f"Config rule: {config_rule_name}, Compliance: {compliance_type}")
        
        # Handle compliance violations
        if compliance_type == 'NON_COMPLIANT':
            result = handle_compliance_violation(config_rule_name, detail)
        else:
            result = f"Compliance check passed for rule: {config_rule_name}"
        
        # Send notification
        if compliance_sns_topic_arn:
            send_compliance_notification(compliance_sns_topic_arn, config_rule_name, compliance_type, result)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Compliance monitoring completed',
                'rule': config_rule_name,
                'compliance': compliance_type,
                'action': result
            })
        }
        
    except Exception as e:
        logger.error(f"Error in compliance monitoring: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def handle_compliance_violation(rule_name, detail):
    """Handle compliance violation"""
    logger.info(f"Handling compliance violation for rule: {rule_name}")
    
    # Get detailed compliance information
    evaluation_result = detail.get('newEvaluationResult', {})
    resource_type = evaluation_result.get('evaluationResultIdentifier', {}).get('evaluationResultQualifier', {}).get('resourceType')
    resource_id = evaluation_result.get('evaluationResultIdentifier', {}).get('evaluationResultQualifier', {}).get('resourceId')
    
    logger.info(f"Non-compliant resource: {resource_type} - {resource_id}")
    
    # Handle different types of compliance violations
    if 'security-group' in rule_name.lower():
        return handle_security_group_violation(resource_id, evaluation_result)
    elif 'ebs' in rule_name.lower():
        return handle_ebs_violation(resource_id, evaluation_result)
    elif 's3' in rule_name.lower():
        return handle_s3_violation(resource_id, evaluation_result)
    elif 'iam' in rule_name.lower():
        return handle_iam_violation(resource_id, evaluation_result)
    else:
        return handle_generic_compliance_violation(rule_name, resource_id, evaluation_result)

def handle_security_group_violation(resource_id, evaluation_result):
    """Handle security group compliance violation"""
    logger.info(f"Handling security group violation: {resource_id}")
    
    try:
        # Get security group details
        response = ec2_client.describe_security_groups(GroupIds=[resource_id])
        security_group = response['SecurityGroups'][0]
        
        # Check for overly permissive rules
        actions_taken = []
        
        for rule in security_group['IpPermissions']:
            for ip_range in rule.get('IpRanges', []):
                if ip_range.get('CidrIp') == '0.0.0.0/0':
                    # Remove overly permissive rule
                    try:
                        ec2_client.revoke_security_group_ingress(
                            GroupId=resource_id,
                            IpPermissions=[rule]
                        )
                        actions_taken.append(f"Removed overly permissive rule: {ip_range.get('CidrIp')}")
                    except Exception as e:
                        logger.error(f"Failed to remove rule: {str(e)}")
        
        if actions_taken:
            return f"Security group {resource_id} remediated: {'; '.join(actions_taken)}"
        else:
            return f"Security group {resource_id} violation analyzed - manual review required"
            
    except Exception as e:
        logger.error(f"Failed to handle security group violation: {str(e)}")
        return f"Failed to remediate security group {resource_id}: {str(e)}"

def handle_ebs_violation(resource_id, evaluation_result):
    """Handle EBS compliance violation"""
    logger.info(f"Handling EBS violation: {resource_id}")
    
    try:
        # Check if EBS volume is encrypted
        response = ec2_client.describe_volumes(VolumeIds=[resource_id])
        volume = response['Volumes'][0]
        
        if not volume.get('Encrypted'):
            # Enable encryption (this would require creating a snapshot and new volume)
            return f"EBS volume {resource_id} is not encrypted - manual remediation required"
        else:
            return f"EBS volume {resource_id} is already encrypted"
            
    except Exception as e:
        logger.error(f"Failed to handle EBS violation: {str(e)}")
        return f"Failed to check EBS volume {resource_id}: {str(e)}"

def handle_s3_violation(resource_id, evaluation_result):
    """Handle S3 compliance violation"""
    logger.info(f"Handling S3 violation: {resource_id}")
    
    try:
        s3_client = boto3.client('s3')
        
        # Check bucket encryption
        try:
            response = s3_client.get_bucket_encryption(Bucket=resource_id)
            return f"S3 bucket {resource_id} is encrypted"
        except s3_client.exceptions.ClientError as e:
            if e.response['Error']['Code'] == 'ServerSideEncryptionConfigurationNotFoundError':
                # Enable default encryption
                s3_client.put_bucket_encryption(
                    Bucket=resource_id,
                    ServerSideEncryptionConfiguration={
                        'Rules': [
                            {
                                'ApplyServerSideEncryptionByDefault': {
                                    'SSEAlgorithm': 'AES256'
                                }
                            }
                        ]
                    }
                )
                return f"Enabled encryption for S3 bucket {resource_id}"
            else:
                raise e
                
    except Exception as e:
        logger.error(f"Failed to handle S3 violation: {str(e)}")
        return f"Failed to remediate S3 bucket {resource_id}: {str(e)}"

def handle_iam_violation(resource_id, evaluation_result):
    """Handle IAM compliance violation"""
    logger.info(f"Handling IAM violation: {resource_id}")
    
    try:
        iam_client = boto3.client('iam')
        
        # Check if it's a user, role, or policy
        if resource_id.startswith('user/'):
            return handle_iam_user_violation(resource_id, iam_client)
        elif resource_id.startswith('role/'):
            return handle_iam_role_violation(resource_id, iam_client)
        elif resource_id.startswith('policy/'):
            return handle_iam_policy_violation(resource_id, iam_client)
        else:
            return f"IAM resource {resource_id} violation analyzed - manual review required"
            
    except Exception as e:
        logger.error(f"Failed to handle IAM violation: {str(e)}")
        return f"Failed to remediate IAM resource {resource_id}: {str(e)}"

def handle_iam_user_violation(resource_id, iam_client):
    """Handle IAM user compliance violation"""
    user_name = resource_id.replace('user/', '')
    
    try:
        # Check if user has MFA enabled
        response = iam_client.list_mfa_devices(UserName=user_name)
        if not response['MFADevices']:
            return f"IAM user {user_name} does not have MFA enabled - manual remediation required"
        else:
            return f"IAM user {user_name} has MFA enabled"
            
    except Exception as e:
        logger.error(f"Failed to check IAM user MFA: {str(e)}")
        return f"Failed to check IAM user {user_name}: {str(e)}"

def handle_iam_role_violation(resource_id, iam_client):
    """Handle IAM role compliance violation"""
    role_name = resource_id.replace('role/', '')
    
    try:
        # Check role trust policy
        response = iam_client.get_role(RoleName=role_name)
        trust_policy = response['Role']['AssumeRolePolicyDocument']
        
        # Check for overly permissive trust policies
        for statement in trust_policy.get('Statement', []):
            if statement.get('Effect') == 'Allow':
                principal = statement.get('Principal', {})
                if principal.get('AWS') == '*':
                    return f"IAM role {role_name} has overly permissive trust policy - manual remediation required"
        
        return f"IAM role {role_name} trust policy is compliant"
        
    except Exception as e:
        logger.error(f"Failed to check IAM role: {str(e)}")
        return f"Failed to check IAM role {role_name}: {str(e)}"

def handle_iam_policy_violation(resource_id, iam_client):
    """Handle IAM policy compliance violation"""
    policy_arn = resource_id.replace('policy/', 'arn:aws:iam::')
    
    try:
        # Get policy details
        response = iam_client.get_policy(PolicyArn=policy_arn)
        policy_version = response['Policy']['DefaultVersionId']
        
        policy_response = iam_client.get_policy_version(
            PolicyArn=policy_arn,
            VersionId=policy_version
        )
        
        policy_document = policy_response['PolicyVersion']['Document']
        
        # Check for overly permissive policies
        for statement in policy_document.get('Statement', []):
            if statement.get('Effect') == 'Allow':
                if statement.get('Action') == '*' and statement.get('Resource') == '*':
                    return f"IAM policy {policy_arn} is overly permissive - manual remediation required"
        
        return f"IAM policy {policy_arn} is compliant"
        
    except Exception as e:
        logger.error(f"Failed to check IAM policy: {str(e)}")
        return f"Failed to check IAM policy {policy_arn}: {str(e)}"

def handle_generic_compliance_violation(rule_name, resource_id, evaluation_result):
    """Handle generic compliance violation"""
    logger.info(f"Handling generic compliance violation: {rule_name} - {resource_id}")
    
    # Log the violation for manual review
    violation_details = {
        'rule_name': rule_name,
        'resource_id': resource_id,
        'compliance_type': evaluation_result.get('complianceType'),
        'annotation': evaluation_result.get('annotation', 'No annotation provided')
    }
    
    logger.info(f"Compliance violation details: {json.dumps(violation_details)}")
    
    return f"Generic compliance violation for {rule_name} - {resource_id} logged for manual review"

def send_compliance_notification(sns_topic_arn, rule_name, compliance_type, action_taken):
    """Send compliance notification to SNS topic"""
    try:
        message = f"""
Compliance Alert

Rule: {rule_name}
Compliance Status: {compliance_type}
Action Taken: {action_taken}
Timestamp: {datetime.now().isoformat()}

This is an automated response to a compliance violation.
        """
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=f"Compliance Alert: {rule_name}",
            Message=message
        )
        
        logger.info(f"Compliance notification sent for rule: {rule_name}")
        
    except Exception as e:
        logger.error(f"Failed to send compliance notification: {str(e)}")
