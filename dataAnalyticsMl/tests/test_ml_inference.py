"""
Comprehensive Test Suite for ML Inference Lambda Function
"""

import json
import pytest
import boto3
from unittest.mock import Mock, patch, MagicMock
from moto import mock_sagemaker, mock_redshift
import sys
import os

# Import the function to test
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'lambda_functions'))
from ml_inference import (
    lambda_handler,
    extract_features,
    get_prediction,
    store_prediction,
    validate_request,
    get_user_history
)

class TestMLInference:
    """Test class for ML inference functionality"""

    def setup_method(self):
        """Setup test data and mocks"""
        self.sample_request = {
            "user_id": "user_000001",
            "user_age": 35,
            "income": 50000,
            "session_duration": 1800,
            "is_premium_user": True,
            "has_previous_purchase": False,
            "page_views": 5,
            "time_on_site": 600,
            "bounce_rate": 0.2
        }
        
        self.sample_event = {
            "body": json.dumps(self.sample_request)
        }

    @mock_sagemaker
    @mock_redshift
    def test_lambda_handler_success(self):
        """Test successful lambda handler execution"""
        with patch.dict(os.environ, {
            'SAGEMAKER_ENDPOINT': 'test-endpoint',
            'REDSHIFT_CLUSTER_ID': 'test-cluster'
        }):
            with patch('ml_inference.get_prediction') as mock_prediction, \
                 patch('ml_inference.store_prediction') as mock_store:
                
                mock_prediction.return_value = {
                    'prediction': 0.8,
                    'confidence': 0.9,
                    'probability': 0.85
                }
                
                result = lambda_handler(self.sample_event, None)
                
                assert result['statusCode'] == 200
                body = json.loads(result['body'])
                assert 'prediction' in body
                assert 'features' in body
                assert 'timestamp' in body

    def test_lambda_handler_invalid_request(self):
        """Test lambda handler with invalid request"""
        invalid_event = {
            "body": json.dumps({"invalid": "data"})
        }
        
        with patch.dict(os.environ, {
            'SAGEMAKER_ENDPOINT': 'test-endpoint',
            'REDSHIFT_CLUSTER_ID': 'test-cluster'
        }):
            with patch('ml_inference.get_prediction') as mock_prediction:
                mock_prediction.return_value = {
                    'prediction': 0.0,
                    'confidence': 0.0,
                    'probability': 0.0
                }
                
                result = lambda_handler(invalid_event, None)
                
                assert result['statusCode'] == 200
                body = json.loads(result['body'])
                assert 'prediction' in body

    def test_lambda_handler_error(self):
        """Test lambda handler with error"""
        with patch.dict(os.environ, {
            'SAGEMAKER_ENDPOINT': 'test-endpoint',
            'REDSHIFT_CLUSTER_ID': 'test-cluster'
        }):
            with patch('ml_inference.extract_features') as mock_extract:
                mock_extract.side_effect = Exception("Feature extraction error")
                
                result = lambda_handler(self.sample_event, None)
                
                assert result['statusCode'] == 500
                body = json.loads(result['body'])
                assert 'error' in body

    def test_extract_features_success(self):
        """Test successful feature extraction"""
        features = extract_features(self.sample_request)
        
        assert len(features) == 8
        assert features[0] == 0.35  # user_age / 100
        assert features[1] == 0.5   # income / 100000
        assert features[2] == 0.5   # session_duration / 3600
        assert features[3] == 1.0   # is_premium_user
        assert features[4] == 0.0   # has_previous_purchase
        assert features[5] == 0.05  # page_views / 100
        assert features[6] == 0.167  # time_on_site / 3600 (approximately)
        assert features[7] == 0.2   # bounce_rate / 100

    def test_extract_features_missing_data(self):
        """Test feature extraction with missing data"""
        incomplete_request = {
            "user_id": "user_000001",
            "user_age": 35
        }
        
        features = extract_features(incomplete_request)
        
        assert len(features) == 8
        assert features[0] == 0.35  # user_age / 100
        assert features[1] == 0.0   # income default
        assert features[2] == 0.0   # session_duration default
        assert features[3] == 0.0   # is_premium_user default
        assert features[4] == 0.0   # has_previous_purchase default
        assert features[5] == 0.0   # page_views default
        assert features[6] == 0.0   # time_on_site default
        assert features[7] == 0.0   # bounce_rate default

    def test_extract_features_invalid_data(self):
        """Test feature extraction with invalid data types"""
        invalid_request = {
            "user_id": "user_000001",
            "user_age": "invalid_age",
            "income": "invalid_income"
        }
        
        features = extract_features(invalid_request)
        
        # Should handle invalid data gracefully
        assert len(features) == 8
        assert all(isinstance(f, float) for f in features)

    @patch('ml_inference.sagemaker_client')
    def test_get_prediction_success(self, mock_sagemaker):
        """Test successful prediction"""
        mock_response = {
            'Body': Mock()
        }
        mock_response['Body'].read.return_value.decode.return_value = json.dumps({
            'predictions': [{
                'prediction': 0.8,
                'confidence': 0.9,
                'probability': 0.85
            }]
        })
        mock_sagemaker.invoke_endpoint.return_value = mock_response
        
        with patch.dict(os.environ, {'SAGEMAKER_ENDPOINT': 'test-endpoint'}):
            result = get_prediction([0.35, 0.5, 0.5, 1.0, 0.0, 0.05, 0.167, 0.2])
            
            assert result['prediction'] == 0.8
            assert result['confidence'] == 0.9
            assert result['probability'] == 0.85

    @patch('ml_inference.sagemaker_client')
    def test_get_prediction_empty_response(self, mock_sagemaker):
        """Test prediction with empty response"""
        mock_response = {
            'Body': Mock()
        }
        mock_response['Body'].read.return_value.decode.return_value = json.dumps({
            'predictions': []
        })
        mock_sagemaker.invoke_endpoint.return_value = mock_response
        
        with patch.dict(os.environ, {'SAGEMAKER_ENDPOINT': 'test-endpoint'}):
            result = get_prediction([0.35, 0.5, 0.5, 1.0, 0.0, 0.05, 0.167, 0.2])
            
            assert result['prediction'] == 0.0
            assert result['confidence'] == 0.0
            assert result['probability'] == 0.0

    @patch('ml_inference.sagemaker_client')
    def test_get_prediction_error(self, mock_sagemaker):
        """Test prediction with error"""
        mock_sagemaker.invoke_endpoint.side_effect = Exception("SageMaker error")
        
        with patch.dict(os.environ, {'SAGEMAKER_ENDPOINT': 'test-endpoint'}):
            result = get_prediction([0.35, 0.5, 0.5, 1.0, 0.0, 0.05, 0.167, 0.2])
            
            assert result['prediction'] == 0.0
            assert result['confidence'] == 0.0
            assert result['probability'] == 0.0
            assert 'error' in result

    @patch('ml_inference.redshift_client')
    def test_store_prediction_success(self, mock_redshift):
        """Test successful prediction storage"""
        mock_redshift.execute_statement.return_value = {'Id': 'test-id'}
        
        with patch.dict(os.environ, {'REDSHIFT_CLUSTER_ID': 'test-cluster'}):
            prediction = {
                'prediction': 0.8,
                'confidence': 0.9,
                'probability': 0.85
            }
            
            store_prediction(self.sample_request, prediction)
            mock_redshift.execute_statement.assert_called_once()

    @patch('ml_inference.redshift_client')
    def test_store_prediction_error(self, mock_redshift):
        """Test prediction storage with error"""
        mock_redshift.execute_statement.side_effect = Exception("Redshift error")
        
        with patch.dict(os.environ, {'REDSHIFT_CLUSTER_ID': 'test-cluster'}):
            prediction = {
                'prediction': 0.8,
                'confidence': 0.9,
                'probability': 0.85
            }
            
            # Should not raise exception
            store_prediction(self.sample_request, prediction)

    def test_validate_request_success(self):
        """Test successful request validation"""
        assert validate_request(self.sample_request) == True

    def test_validate_request_missing_user_id(self):
        """Test request validation with missing user_id"""
        invalid_request = {
            "user_age": 35,
            "income": 50000
        }
        
        assert validate_request(invalid_request) == False

    def test_validate_request_invalid_data_types(self):
        """Test request validation with invalid data types"""
        invalid_request = {
            "user_id": "user_000001",
            "user_age": "invalid_age",
            "income": "invalid_income"
        }
        
        assert validate_request(invalid_request) == False

    @patch('ml_inference.redshift_client')
    def test_get_user_history_success(self, mock_redshift):
        """Test successful user history retrieval"""
        mock_redshift.execute_statement.return_value = {'Id': 'test-id'}
        
        with patch.dict(os.environ, {'REDSHIFT_CLUSTER_ID': 'test-cluster'}):
            result = get_user_history("user_000001")
            
            assert 'total_events' in result
            assert 'avg_value' in result
            assert 'last_activity' in result

    @patch('ml_inference.redshift_client')
    def test_get_user_history_error(self, mock_redshift):
        """Test user history retrieval with error"""
        mock_redshift.execute_statement.side_effect = Exception("Redshift error")
        
        with patch.dict(os.environ, {'REDSHIFT_CLUSTER_ID': 'test-cluster'}):
            result = get_user_history("user_000001")
            
            assert result['total_events'] == 0
            assert result['avg_value'] == 0.0
            assert result['last_activity'] is None

    def test_performance_benchmarks(self):
        """Test performance benchmarks"""
        import time
        
        # Test feature extraction performance
        start_time = time.time()
        features = extract_features(self.sample_request)
        extraction_time = time.time() - start_time
        
        # Should extract features within 10ms
        assert extraction_time < 0.01
        
        # Test prediction performance
        with patch.dict(os.environ, {'SAGEMAKER_ENDPOINT': 'test-endpoint'}):
            with patch('ml_inference.sagemaker_client') as mock_sagemaker:
                mock_response = {
                    'Body': Mock()
                }
                mock_response['Body'].read.return_value.decode.return_value = json.dumps({
                    'predictions': [{
                        'prediction': 0.8,
                        'confidence': 0.9,
                        'probability': 0.85
                    }]
                })
                mock_sagemaker.invoke_endpoint.return_value = mock_response
                
                start_time = time.time()
                prediction = get_prediction(features)
                prediction_time = time.time() - start_time
                
                # Should get prediction within 100ms
                assert prediction_time < 0.1

    def test_edge_cases(self):
        """Test edge cases and boundary conditions"""
        # Test with extreme values
        extreme_request = {
            "user_id": "user_000001",
            "user_age": 0,
            "income": 0,
            "session_duration": 0,
            "is_premium_user": False,
            "has_previous_purchase": False,
            "page_views": 0,
            "time_on_site": 0,
            "bounce_rate": 0
        }
        
        features = extract_features(extreme_request)
        assert len(features) == 8
        assert all(f >= 0 for f in features)
        
        # Test with maximum values
        max_request = {
            "user_id": "user_000001",
            "user_age": 100,
            "income": 1000000,
            "session_duration": 86400,  # 24 hours
            "is_premium_user": True,
            "has_previous_purchase": True,
            "page_views": 1000,
            "time_on_site": 86400,  # 24 hours
            "bounce_rate": 100
        }
        
        features = extract_features(max_request)
        assert len(features) == 8
        assert all(f <= 1.0 for f in features)  # All should be normalized

    def test_concurrent_requests(self):
        """Test handling of concurrent requests"""
        import threading
        import time
        
        results = []
        
        def make_request():
            with patch.dict(os.environ, {
                'SAGEMAKER_ENDPOINT': 'test-endpoint',
                'REDSHIFT_CLUSTER_ID': 'test-cluster'
            }):
                with patch('ml_inference.get_prediction') as mock_prediction, \
                     patch('ml_inference.store_prediction') as mock_store:
                    
                    mock_prediction.return_value = {
                        'prediction': 0.8,
                        'confidence': 0.9,
                        'probability': 0.85
                    }
                    
                    result = lambda_handler(self.sample_event, None)
                    results.append(result)
        
        # Create multiple threads
        threads = []
        for i in range(10):
            thread = threading.Thread(target=make_request)
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # Verify all requests succeeded
        assert len(results) == 10
        for result in results:
            assert result['statusCode'] == 200

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
