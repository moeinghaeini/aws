"""
ML Inference Lambda Function
Provides real-time ML predictions via API Gateway
"""

import json
import boto3
import logging
from typing import Dict, List, Any
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sagemaker_client = boto3.client('sagemaker-runtime')
redshift_client = boto3.client('redshift-data')

# Environment variables
SAGEMAKER_ENDPOINT = os.environ.get('SAGEMAKER_ENDPOINT')
REDSHIFT_CLUSTER_ID = os.environ.get('REDSHIFT_CLUSTER_ID')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for ML inference requests
    """
    try:
        # Parse request
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        # Extract features
        features = extract_features(body)
        
        # Get prediction
        prediction = get_prediction(features)
        
        # Store prediction in Redshift for analytics
        store_prediction(body, prediction)
        
        # Return response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'prediction': prediction,
                'features': features,
                'timestamp': context.aws_request_id
            })
        }
        
    except Exception as e:
        logger.error(f"Error in ML inference: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e),
                'message': 'Internal server error'
            })
        }

def extract_features(data: Dict[str, Any]) -> List[float]:
    """
    Extract and normalize features for ML model
    """
    try:
        # Feature extraction logic
        features = [
            float(data.get('user_age', 0)) / 100.0,  # Normalize age
            float(data.get('income', 0)) / 100000.0,  # Normalize income
            float(data.get('session_duration', 0)) / 3600.0,  # Normalize session duration
            1.0 if data.get('is_premium_user', False) else 0.0,
            1.0 if data.get('has_previous_purchase', False) else 0.0,
            float(data.get('page_views', 0)) / 100.0,  # Normalize page views
            float(data.get('time_on_site', 0)) / 3600.0,  # Normalize time on site
            float(data.get('bounce_rate', 0)) / 100.0,  # Normalize bounce rate
        ]
        
        # Ensure we have exactly 8 features
        while len(features) < 8:
            features.append(0.0)
        
        return features[:8]
        
    except Exception as e:
        logger.error(f"Error extracting features: {str(e)}")
        return [0.0] * 8

def get_prediction(features: List[float]) -> Dict[str, Any]:
    """
    Get prediction from SageMaker endpoint
    """
    try:
        # Prepare payload for SageMaker
        payload = json.dumps({
            'instances': [features]
        })
        
        # Call SageMaker endpoint
        response = sagemaker_client.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT,
            ContentType='application/json',
            Body=payload
        )
        
        # Parse response
        result = json.loads(response['Body'].read().decode())
        
        # Extract prediction and confidence
        if 'predictions' in result and len(result['predictions']) > 0:
            prediction_data = result['predictions'][0]
            return {
                'prediction': float(prediction_data.get('prediction', 0.0)),
                'confidence': float(prediction_data.get('confidence', 0.0)),
                'probability': float(prediction_data.get('probability', 0.0))
            }
        else:
            return {
                'prediction': 0.0,
                'confidence': 0.0,
                'probability': 0.0
            }
            
    except Exception as e:
        logger.error(f"Error getting prediction: {str(e)}")
        return {
            'prediction': 0.0,
            'confidence': 0.0,
            'probability': 0.0,
            'error': str(e)
        }

def store_prediction(request_data: Dict[str, Any], prediction: Dict[str, Any]) -> None:
    """
    Store prediction results in Redshift for analytics
    """
    try:
        # Create SQL statement
        sql = f"""
        INSERT INTO ml_predictions (
            user_id, prediction, confidence, probability, 
            features, request_timestamp, response_timestamp
        ) VALUES (
            '{request_data.get('user_id', 'unknown')}',
            {prediction.get('prediction', 0.0)},
            {prediction.get('confidence', 0.0)},
            {prediction.get('probability', 0.0)},
            '{json.dumps(request_data)}',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        );
        """
        
        # Execute SQL
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER_ID,
            Database='analytics',
            Sql=sql
        )
        
        logger.info(f"Stored prediction in Redshift: {response['Id']}")
        
    except Exception as e:
        logger.error(f"Error storing prediction: {str(e)}")
        # Don't raise exception here as it's not critical for the main flow

def validate_request(data: Dict[str, Any]) -> bool:
    """
    Validate the incoming request data
    """
    required_fields = ['user_id']
    
    for field in required_fields:
        if field not in data:
            return False
    
    # Validate data types
    try:
        if 'user_age' in data:
            int(data['user_age'])
        if 'income' in data:
            float(data['income'])
        if 'session_duration' in data:
            float(data['session_duration'])
    except (ValueError, TypeError):
        return False
    
    return True

def get_user_history(user_id: str) -> Dict[str, Any]:
    """
    Get user's historical data for context
    """
    try:
        sql = f"""
        SELECT 
            COUNT(*) as total_events,
            AVG(value) as avg_value,
            MAX(timestamp) as last_activity
        FROM events 
        WHERE user_id = '{user_id}'
        AND timestamp >= CURRENT_DATE - INTERVAL '30 days';
        """
        
        response = redshift_client.execute_statement(
            ClusterIdentifier=REDSHIFT_CLUSTER_ID,
            Database='analytics',
            Sql=sql
        )
        
        # Note: In a real implementation, you'd need to poll for the result
        # This is a simplified version
        return {
            'total_events': 0,
            'avg_value': 0.0,
            'last_activity': None
        }
        
    except Exception as e:
        logger.error(f"Error getting user history: {str(e)}")
        return {
            'total_events': 0,
            'avg_value': 0.0,
            'last_activity': None
        }
