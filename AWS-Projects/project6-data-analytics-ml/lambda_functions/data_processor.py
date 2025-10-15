"""
Data Processor Lambda Function
Processes streaming data from Kinesis and stores it in Redshift
"""

import json
import boto3
import base64
import logging
from datetime import datetime
from typing import Dict, List, Any
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
redshift_client = boto3.client('redshift-data')
s3_client = boto3.client('s3')
sagemaker_client = boto3.client('sagemaker-runtime')

# Environment variables
REDSHIFT_CLUSTER_ID = os.environ.get('REDSHIFT_CLUSTER_ID')
REDSHIFT_DATABASE = os.environ.get('REDSHIFT_DATABASE')
S3_BUCKET = os.environ.get('S3_BUCKET')
SAGEMAKER_ENDPOINT = os.environ.get('SAGEMAKER_ENDPOINT')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for processing Kinesis records
    """
    try:
        logger.info(f"Processing {len(event['Records'])} records")
        
        processed_records = []
        failed_records = []
        
        for record in event['Records']:
            try:
                # Decode Kinesis data
                payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
                data = json.loads(payload)
                
                # Process the record
                processed_data = process_record(data)
                
                # Store in Redshift
                store_in_redshift(processed_data)
                
                # Store in S3 for data lake
                store_in_s3(processed_data)
                
                processed_records.append(record['kinesis']['sequenceNumber'])
                
            except Exception as e:
                logger.error(f"Error processing record {record['kinesis']['sequenceNumber']}: {str(e)}")
                failed_records.append(record['kinesis']['sequenceNumber'])
        
        logger.info(f"Successfully processed {len(processed_records)} records")
        if failed_records:
            logger.warning(f"Failed to process {len(failed_records)} records")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': len(processed_records),
                'failed': len(failed_records),
                'processed_records': processed_records,
                'failed_records': failed_records
            })
        }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        raise e

def process_record(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Process and enrich the incoming data record
    """
    try:
        # Add processing timestamp
        data['processed_at'] = datetime.utcnow().isoformat()
        
        # Perform data validation
        validate_data(data)
        
        # Enrich data with additional fields
        data['session_duration'] = calculate_session_duration(data)
        data['user_segment'] = determine_user_segment(data)
        
        # Perform ML inference if applicable
        if data.get('event_type') in ['purchase', 'view', 'click']:
            ml_features = extract_ml_features(data)
            prediction = get_ml_prediction(ml_features)
            data['ml_prediction'] = prediction
        
        return data
        
    except Exception as e:
        logger.error(f"Error processing record: {str(e)}")
        raise e

def validate_data(data: Dict[str, Any]) -> None:
    """
    Validate the incoming data record
    """
    required_fields = ['timestamp', 'user_id', 'event_type']
    
    for field in required_fields:
        if field not in data:
            raise ValueError(f"Missing required field: {field}")
    
    # Validate timestamp format
    try:
        datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
    except ValueError:
        raise ValueError("Invalid timestamp format")
    
    # Validate event_type
    valid_event_types = ['view', 'click', 'purchase', 'signup', 'login', 'logout']
    if data['event_type'] not in valid_event_types:
        raise ValueError(f"Invalid event_type: {data['event_type']}")

def calculate_session_duration(data: Dict[str, Any]) -> int:
    """
    Calculate session duration based on event data
    """
    # This is a simplified calculation
    # In a real scenario, you'd track session start/end times
    if data.get('event_type') == 'login':
        return 0
    elif data.get('event_type') == 'logout':
        return data.get('session_duration', 0)
    else:
        return data.get('session_duration', 0)

def determine_user_segment(data: Dict[str, Any]) -> str:
    """
    Determine user segment based on behavior
    """
    # Simple segmentation logic
    if data.get('event_type') == 'purchase':
        return 'high_value'
    elif data.get('value', 0) > 100:
        return 'medium_value'
    else:
        return 'low_value'

def extract_ml_features(data: Dict[str, Any]) -> List[float]:
    """
    Extract features for ML model
    """
    features = [
        float(data.get('value', 0)),
        float(data.get('session_duration', 0)),
        1.0 if data.get('event_type') == 'purchase' else 0.0,
        1.0 if data.get('user_segment') == 'high_value' else 0.0
    ]
    return features

def get_ml_prediction(features: List[float]) -> Dict[str, Any]:
    """
    Get ML prediction from SageMaker endpoint
    """
    try:
        payload = json.dumps({
            'instances': [features]
        })
        
        response = sagemaker_client.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT,
            ContentType='application/json',
            Body=payload
        )
        
        result = json.loads(response['Body'].read().decode())
        return result
        
    except Exception as e:
        logger.error(f"Error getting ML prediction: {str(e)}")
        return {'prediction': 0.0, 'confidence': 0.0}

def store_in_redshift(data: Dict[str, Any]) -> None:
    """
    Store processed data in Redshift
    """
    try:
        # Create SQL statement
        sql = f"""
        INSERT INTO events (
            timestamp, user_id, event_type, value, 
            session_duration, user_segment, ml_prediction, processed_at
        ) VALUES (
            '{data['timestamp']}', 
            '{data['user_id']}', 
            '{data['event_type']}', 
            {data.get('value', 0)},
            {data.get('session_duration', 0)},
            '{data.get('user_segment', 'unknown')}',
            '{json.dumps(data.get('ml_prediction', {}))}',
            '{data['processed_at']}'
        );
        """
        
        # Execute SQL
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER_ID,
            Database=REDSHIFT_DATABASE,
            Sql=sql
        )
        
        logger.info(f"Stored record in Redshift: {response['Id']}")
        
    except Exception as e:
        logger.error(f"Error storing in Redshift: {str(e)}")
        raise e

def store_in_s3(data: Dict[str, Any]) -> None:
    """
    Store processed data in S3 data lake
    """
    try:
        # Create S3 key with partitioning
        timestamp = datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
        s3_key = f"events/year={timestamp.year}/month={timestamp.month:02d}/day={timestamp.day:02d}/hour={timestamp.hour:02d}/{data['user_id']}_{timestamp.isoformat()}.json"
        
        # Upload to S3
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=json.dumps(data),
            ContentType='application/json'
        )
        
        logger.info(f"Stored record in S3: {s3_key}")
        
    except Exception as e:
        logger.error(f"Error storing in S3: {str(e)}")
        raise e
