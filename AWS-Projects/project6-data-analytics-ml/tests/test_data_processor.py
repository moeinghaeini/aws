"""
Comprehensive Test Suite for Data Processor Lambda Function
"""

import json
import pytest
import boto3
from unittest.mock import Mock, patch, MagicMock
from moto import mock_kinesis, mock_s3, mock_redshift, mock_sagemaker
import base64
from datetime import datetime

# Import the function to test
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'lambda_functions'))
from data_processor import (
    lambda_handler,
    process_record,
    validate_data,
    calculate_session_duration,
    determine_user_segment,
    extract_ml_features,
    get_ml_prediction,
    store_in_redshift,
    store_in_s3
)

class TestDataProcessor:
    """Test class for data processor functionality"""

    def setup_method(self):
        """Setup test data and mocks"""
        self.sample_event = {
            "Records": [
                {
                    "kinesis": {
                        "data": base64.b64encode(json.dumps({
                            "timestamp": "2024-01-15T10:00:00Z",
                            "user_id": "user_000001",
                            "event_type": "view",
                            "value": 25.50
                        }).encode()).decode(),
                        "sequenceNumber": "1234567890"
                    }
                }
            ]
        }
        
        self.sample_data = {
            "timestamp": "2024-01-15T10:00:00Z",
            "user_id": "user_000001",
            "event_type": "view",
            "value": 25.50
        }

    @mock_kinesis
    @mock_s3
    @mock_redshift
    @mock_sagemaker
    def test_lambda_handler_success(self):
        """Test successful lambda handler execution"""
        with patch.dict(os.environ, {
            'REDSHIFT_CLUSTER_ID': 'test-cluster',
            'REDSHIFT_DATABASE': 'analytics',
            'S3_BUCKET': 'test-bucket',
            'SAGEMAKER_ENDPOINT': 'test-endpoint'
        }):
            with patch('data_processor.store_in_redshift') as mock_redshift, \
                 patch('data_processor.store_in_s3') as mock_s3, \
                 patch('data_processor.get_ml_prediction') as mock_ml:
                
                mock_ml.return_value = {'prediction': 0.8, 'confidence': 0.9}
                
                result = lambda_handler(self.sample_event, None)
                
                assert result['statusCode'] == 200
                body = json.loads(result['body'])
                assert body['processed'] == 1
                assert body['failed'] == 0
                assert len(body['processed_records']) == 1

    def test_lambda_handler_invalid_data(self):
        """Test lambda handler with invalid data"""
        invalid_event = {
            "Records": [
                {
                    "kinesis": {
                        "data": base64.b64encode(json.dumps({
                            "invalid": "data"
                        }).encode()).decode(),
                        "sequenceNumber": "1234567890"
                    }
                }
            ]
        }
        
        with patch.dict(os.environ, {
            'REDSHIFT_CLUSTER_ID': 'test-cluster',
            'REDSHIFT_DATABASE': 'analytics',
            'S3_BUCKET': 'test-bucket',
            'SAGEMAKER_ENDPOINT': 'test-endpoint'
        }):
            result = lambda_handler(invalid_event, None)
            
            assert result['statusCode'] == 200
            body = json.loads(result['body'])
            assert body['processed'] == 0
            assert body['failed'] == 1

    def test_process_record_success(self):
        """Test successful record processing"""
        with patch('data_processor.validate_data') as mock_validate, \
             patch('data_processor.calculate_session_duration') as mock_duration, \
             patch('data_processor.determine_user_segment') as mock_segment, \
             patch('data_processor.extract_ml_features') as mock_features, \
             patch('data_processor.get_ml_prediction') as mock_ml:
            
            mock_validate.return_value = None
            mock_duration.return_value = 300
            mock_segment.return_value = 'medium_value'
            mock_features.return_value = [0.5, 0.3, 0.8, 0.2]
            mock_ml.return_value = {'prediction': 0.7, 'confidence': 0.8}
            
            result = process_record(self.sample_data)
            
            assert 'processed_at' in result
            assert result['session_duration'] == 300
            assert result['user_segment'] == 'medium_value'
            assert 'ml_prediction' in result

    def test_validate_data_success(self):
        """Test successful data validation"""
        validate_data(self.sample_data)
        # Should not raise any exception

    def test_validate_data_missing_fields(self):
        """Test data validation with missing required fields"""
        invalid_data = {"timestamp": "2024-01-15T10:00:00Z"}
        
        with pytest.raises(ValueError, match="Missing required field"):
            validate_data(invalid_data)

    def test_validate_data_invalid_timestamp(self):
        """Test data validation with invalid timestamp"""
        invalid_data = {
            "timestamp": "invalid-timestamp",
            "user_id": "user_000001",
            "event_type": "view"
        }
        
        with pytest.raises(ValueError, match="Invalid timestamp format"):
            validate_data(invalid_data)

    def test_validate_data_invalid_event_type(self):
        """Test data validation with invalid event type"""
        invalid_data = {
            "timestamp": "2024-01-15T10:00:00Z",
            "user_id": "user_000001",
            "event_type": "invalid_event"
        }
        
        with pytest.raises(ValueError, match="Invalid event_type"):
            validate_data(invalid_data)

    def test_calculate_session_duration(self):
        """Test session duration calculation"""
        # Test login event
        login_data = {"event_type": "login"}
        assert calculate_session_duration(login_data) == 0
        
        # Test logout event
        logout_data = {"event_type": "logout", "session_duration": 1800}
        assert calculate_session_duration(logout_data) == 1800
        
        # Test other events
        other_data = {"event_type": "view", "session_duration": 300}
        assert calculate_session_duration(other_data) == 300

    def test_determine_user_segment(self):
        """Test user segment determination"""
        # High value user
        high_value_data = {"event_type": "purchase"}
        assert determine_user_segment(high_value_data) == 'high_value'
        
        # Medium value user
        medium_value_data = {"value": 150}
        assert determine_user_segment(medium_value_data) == 'medium_value'
        
        # Low value user
        low_value_data = {"value": 50}
        assert determine_user_segment(low_value_data) == 'low_value'

    def test_extract_ml_features(self):
        """Test ML feature extraction"""
        test_data = {
            "value": 100,
            "session_duration": 1800,
            "event_type": "purchase",
            "user_segment": "high_value"
        }
        
        features = extract_ml_features(test_data)
        
        assert len(features) == 4
        assert features[0] == 100.0  # value
        assert features[1] == 1800.0  # session_duration
        assert features[2] == 1.0  # is_purchase
        assert features[3] == 1.0  # is_high_value

    @patch('data_processor.sagemaker_client')
    def test_get_ml_prediction_success(self, mock_sagemaker):
        """Test successful ML prediction"""
        mock_response = {
            'Body': Mock()
        }
        mock_response['Body'].read.return_value.decode.return_value = json.dumps({
            'predictions': [{'prediction': 0.8, 'confidence': 0.9}]
        })
        mock_sagemaker.invoke_endpoint.return_value = mock_response
        
        with patch.dict(os.environ, {'SAGEMAKER_ENDPOINT': 'test-endpoint'}):
            result = get_ml_prediction([0.5, 0.3, 0.8, 0.2])
            
            assert result['prediction'] == 0.8
            assert result['confidence'] == 0.9

    @patch('data_processor.sagemaker_client')
    def test_get_ml_prediction_error(self, mock_sagemaker):
        """Test ML prediction with error"""
        mock_sagemaker.invoke_endpoint.side_effect = Exception("SageMaker error")
        
        with patch.dict(os.environ, {'SAGEMAKER_ENDPOINT': 'test-endpoint'}):
            result = get_ml_prediction([0.5, 0.3, 0.8, 0.2])
            
            assert result['prediction'] == 0.0
            assert result['confidence'] == 0.0

    @patch('data_processor.redshift_client')
    def test_store_in_redshift_success(self, mock_redshift):
        """Test successful Redshift storage"""
        mock_redshift.execute_statement.return_value = {'Id': 'test-id'}
        
        with patch.dict(os.environ, {
            'REDSHIFT_CLUSTER_ID': 'test-cluster',
            'REDSHIFT_DATABASE': 'analytics'
        }):
            store_in_redshift(self.sample_data)
            mock_redshift.execute_statement.assert_called_once()

    @patch('data_processor.redshift_client')
    def test_store_in_redshift_error(self, mock_redshift):
        """Test Redshift storage with error"""
        mock_redshift.execute_statement.side_effect = Exception("Redshift error")
        
        with patch.dict(os.environ, {
            'REDSHIFT_CLUSTER_ID': 'test-cluster',
            'REDSHIFT_DATABASE': 'analytics'
        }):
            with pytest.raises(Exception, match="Redshift error"):
                store_in_redshift(self.sample_data)

    @patch('data_processor.s3_client')
    def test_store_in_s3_success(self, mock_s3):
        """Test successful S3 storage"""
        with patch.dict(os.environ, {'S3_BUCKET': 'test-bucket'}):
            store_in_s3(self.sample_data)
            mock_s3.put_object.assert_called_once()

    @patch('data_processor.s3_client')
    def test_store_in_s3_error(self, mock_s3):
        """Test S3 storage with error"""
        mock_s3.put_object.side_effect = Exception("S3 error")
        
        with patch.dict(os.environ, {'S3_BUCKET': 'test-bucket'}):
            with pytest.raises(Exception, match="S3 error"):
                store_in_s3(self.sample_data)

    def test_performance_benchmarks(self):
        """Test performance benchmarks"""
        import time
        
        # Test processing time for single record
        start_time = time.time()
        process_record(self.sample_data)
        processing_time = time.time() - start_time
        
        # Should process within 100ms
        assert processing_time < 0.1
        
        # Test batch processing performance
        batch_event = {
            "Records": [self.sample_event["Records"][0]] * 100
        }
        
        start_time = time.time()
        with patch.dict(os.environ, {
            'REDSHIFT_CLUSTER_ID': 'test-cluster',
            'REDSHIFT_DATABASE': 'analytics',
            'S3_BUCKET': 'test-bucket',
            'SAGEMAKER_ENDPOINT': 'test-endpoint'
        }):
            with patch('data_processor.store_in_redshift'), \
                 patch('data_processor.store_in_s3'), \
                 patch('data_processor.get_ml_prediction') as mock_ml:
                
                mock_ml.return_value = {'prediction': 0.8, 'confidence': 0.9}
                lambda_handler(batch_event, None)
        
        batch_processing_time = time.time() - start_time
        
        # Should process 100 records within 5 seconds
        assert batch_processing_time < 5.0

    def test_error_handling_comprehensive(self):
        """Test comprehensive error handling scenarios"""
        error_scenarios = [
            # Invalid JSON in Kinesis data
            {
                "Records": [{
                    "kinesis": {
                        "data": "invalid-base64-data",
                        "sequenceNumber": "1234567890"
                    }
                }]
            },
            # Missing Kinesis data
            {
                "Records": [{
                    "kinesis": {
                        "sequenceNumber": "1234567890"
                    }
                }]
            },
            # Empty Records array
            {"Records": []}
        ]
        
        for scenario in error_scenarios:
            with patch.dict(os.environ, {
                'REDSHIFT_CLUSTER_ID': 'test-cluster',
                'REDSHIFT_DATABASE': 'analytics',
                'S3_BUCKET': 'test-bucket',
                'SAGEMAKER_ENDPOINT': 'test-endpoint'
            }):
                result = lambda_handler(scenario, None)
                assert result['statusCode'] == 200
                body = json.loads(result['body'])
                assert 'processed' in body
                assert 'failed' in body

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
