"""
Pytest configuration and fixtures for the data analytics ML platform tests
"""

import pytest
import boto3
import json
import os
from moto import mock_kinesis, mock_s3, mock_redshift, mock_sagemaker, mock_lambda
from unittest.mock import Mock, patch
import tempfile
import shutil

@pytest.fixture(scope="session")
def aws_credentials():
    """Mock AWS credentials for testing"""
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"

@pytest.fixture
def sample_kinesis_event():
    """Sample Kinesis event for testing"""
    return {
        "Records": [
            {
                "kinesis": {
                    "data": "eyJ0aW1lc3RhbXAiOiIyMDI0LTAxLTE1VDEwOjAwOjAwWiIsInVzZXJfaWQiOiJ1c2VyXzAwMDAwMSIsImV2ZW50X3R5cGUiOiJ2aWV3IiwidmFsdWUiOjI1LjV9",
                    "sequenceNumber": "1234567890"
                }
            }
        ]
    }

@pytest.fixture
def sample_ml_request():
    """Sample ML inference request for testing"""
    return {
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

@pytest.fixture
def sample_data_record():
    """Sample data record for testing"""
    return {
        "timestamp": "2024-01-15T10:00:00Z",
        "user_id": "user_000001",
        "event_type": "view",
        "value": 25.50
    }

@pytest.fixture
def mock_aws_services():
    """Mock AWS services for testing"""
    with mock_kinesis(), mock_s3(), mock_redshift(), mock_sagemaker(), mock_lambda():
        yield

@pytest.fixture
def temp_directory():
    """Temporary directory for test files"""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    shutil.rmtree(temp_dir)

@pytest.fixture
def mock_environment_variables():
    """Mock environment variables for testing"""
    env_vars = {
        'REDSHIFT_CLUSTER_ID': 'test-cluster',
        'REDSHIFT_DATABASE': 'analytics',
        'S3_BUCKET': 'test-bucket',
        'SAGEMAKER_ENDPOINT': 'test-endpoint',
        'SNS_TOPIC_ARN': 'arn:aws:sns:us-east-1:123456789012:test-topic'
    }
    
    with patch.dict(os.environ, env_vars):
        yield env_vars

@pytest.fixture
def mock_cloudwatch_client():
    """Mock CloudWatch client for testing"""
    with patch('boto3.client') as mock_client:
        mock_cloudwatch = Mock()
        mock_client.return_value = mock_cloudwatch
        yield mock_cloudwatch

@pytest.fixture
def mock_sns_client():
    """Mock SNS client for testing"""
    with patch('boto3.client') as mock_client:
        mock_sns = Mock()
        mock_client.return_value = mock_sns
        yield mock_sns

@pytest.fixture
def performance_test_data():
    """Sample data for performance testing"""
    return {
        'kinesis_records': [
            {
                'timestamp': '2024-01-15T10:00:00Z',
                'user_id': f'perf_test_{i}',
                'event_type': 'performance_test',
                'value': 25.50
            }
            for i in range(100)
        ],
        'ml_requests': [
            {
                'user_id': f'ml_test_{i}',
                'user_age': 35,
                'income': 50000,
                'session_duration': 1800,
                'is_premium_user': True,
                'has_previous_purchase': False,
                'page_views': 5,
                'time_on_site': 600,
                'bounce_rate': 0.2
            }
            for i in range(50)
        ]
    }

@pytest.fixture
def cost_optimization_data():
    """Sample data for cost optimization testing"""
    return {
        'current_costs': {
            'total_cost': 1000.0,
            'service_costs': {
                'Amazon Kinesis': 100.0,
                'Amazon Redshift': 400.0,
                'Amazon SageMaker': 200.0,
                'AWS Lambda': 50.0,
                'Amazon S3': 50.0
            }
        },
        'utilization_metrics': {
            'kinesis': {
                'shard_count': 2,
                'utilization_percentage': 25.0,
                'recommendation': 'scale_down'
            },
            'redshift': {
                'node_count': 2,
                'avg_cpu_utilization': 30.0,
                'recommendation': 'scale_down'
            },
            'sagemaker': {
                'instance_count': 1,
                'avg_invocations_per_hour': 5.0,
                'recommendation': 'scale_down'
            }
        }
    }

@pytest.fixture
def data_lineage_sample():
    """Sample data lineage information"""
    return {
        'lineage_id': 'test-lineage-123',
        'source_system': 'kinesis',
        'source_table': 'data-stream',
        'source_column': 'data',
        'target_system': 'lambda',
        'target_table': 'data-processor',
        'target_column': 'processed-data',
        'transformation_type': 'stream-processing',
        'transformation_logic': 'Real-time data processing and enrichment',
        'data_quality_rules': 'Schema validation, data type checking',
        'created_at': '2024-01-15T10:00:00Z',
        'created_by': 'system',
        'business_owner': 'data-engineering-team'
    }

# Pytest configuration
def pytest_configure(config):
    """Configure pytest with custom markers"""
    config.addinivalue_line(
        "markers", "unit: mark test as a unit test"
    )
    config.addinivalue_line(
        "markers", "integration: mark test as an integration test"
    )
    config.addinivalue_line(
        "markers", "performance: mark test as a performance test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )

def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers based on test names"""
    for item in items:
        # Add performance marker to performance tests
        if "performance" in item.name:
            item.add_marker(pytest.mark.performance)
        
        # Add slow marker to tests that might take longer
        if any(keyword in item.name for keyword in ["load", "stress", "end_to_end"]):
            item.add_marker(pytest.mark.slow)
        
        # Add integration marker to integration tests
        if "integration" in item.name:
            item.add_marker(pytest.mark.integration)
        
        # Add unit marker to unit tests
        if "unit" in item.name or not any(marker in item.name for marker in ["integration", "performance"]):
            item.add_marker(pytest.mark.unit)

# Test data generators
class TestDataGenerator:
    """Utility class for generating test data"""
    
    @staticmethod
    def generate_kinesis_records(count: int = 10):
        """Generate sample Kinesis records"""
        import base64
        import uuid
        
        records = []
        for i in range(count):
            record = {
                'timestamp': '2024-01-15T10:00:00Z',
                'user_id': f'user_{uuid.uuid4()}',
                'event_type': 'test_event',
                'value': 25.50
            }
            encoded_data = base64.b64encode(json.dumps(record).encode()).decode()
            records.append({
                'kinesis': {
                    'data': encoded_data,
                    'sequenceNumber': str(1234567890 + i)
                }
            })
        return {'Records': records}
    
    @staticmethod
    def generate_ml_features(count: int = 8):
        """Generate sample ML features"""
        import random
        return [random.uniform(0, 1) for _ in range(count)]
    
    @staticmethod
    def generate_cost_data():
        """Generate sample cost data"""
        return {
            'total_cost': 1000.0,
            'service_costs': {
                'Amazon Kinesis': 100.0,
                'Amazon Redshift': 400.0,
                'Amazon SageMaker': 200.0,
                'AWS Lambda': 50.0,
                'Amazon S3': 50.0
            }
        }

@pytest.fixture
def test_data_generator():
    """Fixture for test data generator"""
    return TestDataGenerator()
