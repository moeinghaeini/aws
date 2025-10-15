import json
import boto3
import logging
import uuid
from datetime import datetime
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

# Get table and topic from environment variables
CONTACT_TABLE = 'contact-submissions'
SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:contact-notifications'  # This will be updated by Terraform

def lambda_handler(event, context):
    """
    BROKEN Lambda function to handle contact form submissions
    This function has intentional issues for debugging practice
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # ISSUE 1: Incorrect body parsing - might cause errors
        body = event.get('body', {})
        if isinstance(body, str):
            # This might fail if the JSON is malformed
            body = json.loads(body)
        
        logger.info(f"Parsed body: {json.dumps(body)}")
        
        # ISSUE 2: Missing validation - allows invalid data through
        # validate_form_data(body)  # This line is commented out!
        
        # ISSUE 3: Hardcoded values that might not exist
        submission_id = process_contact_submission(body)
        
        # ISSUE 4: Notification might fail due to wrong topic ARN
        send_notification_email(body, submission_id)
        
        # ISSUE 5: Missing CORS headers in response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Contact form submitted successfully',
                'submission_id': submission_id,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing contact form: {str(e)}")
        # ISSUE 6: Generic error response without proper CORS headers
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'An error occurred while processing your request'
            })
        }

def validate_form_data(data):
    """
    Validate the form data - This function exists but is not called
    """
    errors = []
    
    # Required fields
    required_fields = ['name', 'email', 'subject', 'message']
    for field in required_fields:
        if not data.get(field):
            errors.append(f'{field} is required')
    
    # Email validation
    email = data.get('email', '')
    if email and '@' not in email:
        errors.append('Invalid email format')
    
    # Message length validation
    message = data.get('message', '')
    if message and len(message) < 10:
        errors.append('Message must be at least 10 characters long')
    
    return {
        'valid': len(errors) == 0,
        'errors': errors
    }

def process_contact_submission(data):
    """
    Store the contact submission in DynamoDB - Has potential issues
    """
    try:
        # Generate unique submission ID
        submission_id = str(uuid.uuid4())
        
        # ISSUE 7: Missing error handling for required fields
        item = {
            'submission_id': submission_id,
            'name': data['name'],  # This will fail if 'name' is not in data
            'email': data['email'],  # This will fail if 'email' is not in data
            'phone': data.get('phone', ''),
            'subject': data['subject'],  # This will fail if 'subject' is not in data
            'message': data['message'],  # This will fail if 'message' is not in data
            'priority': data.get('priority', 'medium'),
            'status': 'new',
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }
        
        logger.info(f"Storing item in DynamoDB: {json.dumps(item)}")
        
        # ISSUE 8: Table name might not exist or have wrong permissions
        table = dynamodb.Table(CONTACT_TABLE)
        table.put_item(Item=item)
        
        logger.info(f"Successfully stored submission {submission_id}")
        return submission_id
        
    except ClientError as e:
        logger.error(f"DynamoDB error: {str(e)}")
        raise Exception(f"Failed to store contact submission: {str(e)}")
    except KeyError as e:
        logger.error(f"Missing required field: {str(e)}")
        raise Exception(f"Missing required field: {str(e)}")
    except Exception as e:
        logger.error(f"Error processing submission: {str(e)}")
        raise

def send_notification_email(data, submission_id):
    """
    Send notification email via SNS - Has potential issues
    """
    try:
        # ISSUE 9: SNS topic ARN might be incorrect
        message = f"""
New Contact Form Submission

Submission ID: {submission_id}
Name: {data.get('name', 'N/A')}
Email: {data.get('email', 'N/A')}
Phone: {data.get('phone', 'N/A')}
Subject: {data.get('subject', 'N/A')}
Priority: {data.get('priority', 'medium')}

Message:
{data.get('message', 'N/A')}

Submitted at: {datetime.utcnow().isoformat()}
        """
        
        # ISSUE 10: SNS publish might fail due to permissions or topic not existing
        response = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"New Contact Form Submission - {data.get('subject', 'Unknown')}",
            Message=message
        )
        
        logger.info(f"Notification sent: {response['MessageId']}")
        
    except ClientError as e:
        logger.error(f"SNS error: {str(e)}")
        # ISSUE 11: Not raising exception - email failure is silent
        pass
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")
        # ISSUE 12: Not raising exception - email failure is silent
        pass

def create_response(status_code, body):
    """
    Create HTTP response - This function exists but is not used
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token'
        },
        'body': json.dumps(body)
    }
