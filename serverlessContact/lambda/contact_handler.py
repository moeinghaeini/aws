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
    Lambda function to handle contact form submissions
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse the request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})
        
        logger.info(f"Parsed body: {json.dumps(body)}")
        
        # Validate required fields
        validation_result = validate_form_data(body)
        if not validation_result['valid']:
            return create_response(400, {
                'error': 'Validation failed',
                'details': validation_result['errors']
            })
        
        # Process the contact form submission
        submission_id = process_contact_submission(body)
        
        # Send notification email
        send_notification_email(body, submission_id)
        
        return create_response(200, {
            'message': 'Contact form submitted successfully',
            'submission_id': submission_id,
            'timestamp': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error processing contact form: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error',
            'message': 'An error occurred while processing your request'
        })

def validate_form_data(data):
    """
    Validate the form data
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
    
    # Phone validation (if provided)
    phone = data.get('phone', '')
    if phone and not phone.replace('-', '').replace('(', '').replace(')', '').replace(' ', '').isdigit():
        errors.append('Invalid phone number format')
    
    return {
        'valid': len(errors) == 0,
        'errors': errors
    }

def process_contact_submission(data):
    """
    Store the contact submission in DynamoDB
    """
    try:
        # Generate unique submission ID
        submission_id = str(uuid.uuid4())
        
        # Prepare the item for DynamoDB
        item = {
            'submission_id': submission_id,
            'name': data['name'],
            'email': data['email'],
            'phone': data.get('phone', ''),
            'subject': data['subject'],
            'message': data['message'],
            'priority': data.get('priority', 'medium'),
            'status': 'new',
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }
        
        logger.info(f"Storing item in DynamoDB: {json.dumps(item)}")
        
        # Store in DynamoDB
        table = dynamodb.Table(CONTACT_TABLE)
        table.put_item(Item=item)
        
        logger.info(f"Successfully stored submission {submission_id}")
        return submission_id
        
    except ClientError as e:
        logger.error(f"DynamoDB error: {str(e)}")
        raise Exception(f"Failed to store contact submission: {str(e)}")
    except Exception as e:
        logger.error(f"Error processing submission: {str(e)}")
        raise

def send_notification_email(data, submission_id):
    """
    Send notification email via SNS
    """
    try:
        # Prepare email message
        message = f"""
New Contact Form Submission

Submission ID: {submission_id}
Name: {data['name']}
Email: {data['email']}
Phone: {data.get('phone', 'N/A')}
Subject: {data['subject']}
Priority: {data.get('priority', 'medium')}

Message:
{data['message']}

Submitted at: {datetime.utcnow().isoformat()}
        """
        
        # Send notification
        response = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"New Contact Form Submission - {data['subject']}",
            Message=message
        )
        
        logger.info(f"Notification sent: {response['MessageId']}")
        
    except ClientError as e:
        logger.error(f"SNS error: {str(e)}")
        # Don't raise exception here - we don't want email failure to break the form submission
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")

def create_response(status_code, body):
    """
    Create HTTP response with CORS headers
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',  # This might be too permissive in production
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token'
        },
        'body': json.dumps(body)
    }
