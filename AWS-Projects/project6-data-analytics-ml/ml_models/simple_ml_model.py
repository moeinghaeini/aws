#!/usr/bin/env python3
"""
Simple ML Model for Data Analytics Platform
Demonstrates a basic machine learning model for user behavior prediction
"""

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.preprocessing import StandardScaler
import json
import os
from typing import Dict, List, Any, Tuple

class SimpleMLModel:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.feature_names = [
            'user_age_normalized',
            'income_normalized', 
            'session_duration_normalized',
            'is_premium_user',
            'has_previous_purchase',
            'page_views_normalized',
            'time_on_site_normalized',
            'bounce_rate'
        ]
        self.target_name = 'will_purchase'
    
    def generate_sample_data(self, n_samples: int = 10000) -> Tuple[np.ndarray, np.ndarray]:
        """Generate sample training data"""
        np.random.seed(42)
        
        # Generate features
        user_age = np.random.normal(35, 15, n_samples)
        income = np.random.normal(50000, 25000, n_samples)
        session_duration = np.random.exponential(300, n_samples)  # seconds
        is_premium = np.random.choice([0, 1], n_samples, p=[0.8, 0.2])
        has_previous_purchase = np.random.choice([0, 1], n_samples, p=[0.6, 0.4])
        page_views = np.random.poisson(5, n_samples)
        time_on_site = np.random.exponential(600, n_samples)  # seconds
        bounce_rate = np.random.beta(2, 5, n_samples)
        
        # Create feature matrix
        X = np.column_stack([
            user_age / 100.0,  # Normalize age
            income / 100000.0,  # Normalize income
            session_duration / 3600.0,  # Normalize session duration
            is_premium,
            has_previous_purchase,
            page_views / 100.0,  # Normalize page views
            time_on_site / 3600.0,  # Normalize time on site
            bounce_rate
        ])
        
        # Generate target variable (will_purchase) based on features
        # Higher probability for premium users, longer sessions, more page views
        purchase_prob = (
            0.1 +  # Base probability
            0.3 * is_premium +  # Premium users more likely to purchase
            0.2 * (session_duration / 3600.0) +  # Longer sessions
            0.1 * (page_views / 100.0) +  # More page views
            0.2 * has_previous_purchase +  # Previous purchasers
            -0.1 * bounce_rate  # Lower bounce rate
        )
        
        # Ensure probabilities are between 0 and 1
        purchase_prob = np.clip(purchase_prob, 0, 1)
        
        # Generate binary target
        y = np.random.binomial(1, purchase_prob, n_samples)
        
        return X, y
    
    def train_model(self, X: np.ndarray, y: np.ndarray) -> Dict[str, Any]:
        """Train the machine learning model"""
        print("Training ML model...")
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Train model
        self.model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=42,
            class_weight='balanced'
        )
        
        self.model.fit(X_train_scaled, y_train)
        
        # Evaluate model
        y_pred = self.model.predict(X_test_scaled)
        y_pred_proba = self.model.predict_proba(X_test_scaled)[:, 1]
        
        # Calculate metrics
        accuracy = self.model.score(X_test_scaled, y_test)
        
        print(f"Model Accuracy: {accuracy:.4f}")
        print("\nClassification Report:")
        print(classification_report(y_test, y_pred))
        
        print("\nConfusion Matrix:")
        print(confusion_matrix(y_test, y_pred))
        
        # Feature importance
        feature_importance = dict(zip(self.feature_names, self.model.feature_importances_))
        print("\nFeature Importance:")
        for feature, importance in sorted(feature_importance.items(), key=lambda x: x[1], reverse=True):
            print(f"{feature}: {importance:.4f}")
        
        return {
            'accuracy': accuracy,
            'feature_importance': feature_importance,
            'classification_report': classification_report(y_test, y_pred, output_dict=True)
        }
    
    def predict(self, features: List[float]) -> Dict[str, Any]:
        """Make prediction for given features"""
        if self.model is None:
            raise ValueError("Model not trained yet")
        
        # Ensure we have the right number of features
        if len(features) != len(self.feature_names):
            raise ValueError(f"Expected {len(self.feature_names)} features, got {len(features)}")
        
        # Convert to numpy array and reshape
        X = np.array(features).reshape(1, -1)
        
        # Scale features
        X_scaled = self.scaler.transform(X)
        
        # Make prediction
        prediction = self.model.predict(X_scaled)[0]
        probability = self.model.predict_proba(X_scaled)[0]
        
        return {
            'prediction': int(prediction),
            'probability': float(probability[1]),  # Probability of positive class
            'confidence': float(max(probability)),  # Confidence in prediction
            'features': dict(zip(self.feature_names, features))
        }
    
    def save_model(self, filepath: str) -> None:
        """Save the trained model"""
        if self.model is None:
            raise ValueError("Model not trained yet")
        
        # Create model package
        model_package = {
            'model': self.model,
            'scaler': self.scaler,
            'feature_names': self.feature_names,
            'target_name': self.target_name
        }
        
        # Save to file
        joblib.dump(model_package, filepath)
        print(f"Model saved to {filepath}")
    
    def load_model(self, filepath: str) -> None:
        """Load a trained model"""
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"Model file not found: {filepath}")
        
        # Load model package
        model_package = joblib.load(filepath)
        
        self.model = model_package['model']
        self.scaler = model_package['scaler']
        self.feature_names = model_package['feature_names']
        self.target_name = model_package['target_name']
        
        print(f"Model loaded from {filepath}")
    
    def create_sagemaker_model(self, model_path: str, s3_bucket: str, s3_key: str) -> None:
        """Create a SageMaker-compatible model package"""
        import tarfile
        
        # Create model directory
        model_dir = "model"
        os.makedirs(model_dir, exist_ok=True)
        
        # Save model
        self.save_model(os.path.join(model_dir, "model.pkl"))
        
        # Create inference script
        inference_script = """
import json
import joblib
import numpy as np

def model_fn(model_dir):
    model_package = joblib.load(f"{model_dir}/model.pkl")
    return model_package

def input_fn(request_body, request_content_type):
    if request_content_type == 'application/json':
        input_data = json.loads(request_body)
        return input_data
    else:
        raise ValueError(f"Unsupported content type: {request_content_type}")

def predict_fn(input_data, model):
    model_obj = model['model']
    scaler = model['scaler']
    
    # Extract features
    if 'instances' in input_data:
        features = input_data['instances'][0]
    else:
        features = input_data
    
    # Convert to numpy array and reshape
    X = np.array(features).reshape(1, -1)
    
    # Scale features
    X_scaled = scaler.transform(X)
    
    # Make prediction
    prediction = model_obj.predict(X_scaled)[0]
    probability = model_obj.predict_proba(X_scaled)[0]
    
    return {
        'prediction': int(prediction),
        'probability': float(probability[1]),
        'confidence': float(max(probability))
    }

def output_fn(prediction, content_type):
    if content_type == 'application/json':
        return json.dumps(prediction)
    else:
        raise ValueError(f"Unsupported content type: {content_type}")
"""
        
        with open(os.path.join(model_dir, "inference.py"), "w") as f:
            f.write(inference_script)
        
        # Create requirements.txt
        requirements = """
scikit-learn==1.3.2
numpy==1.24.3
joblib==1.3.2
"""
        
        with open(os.path.join(model_dir, "requirements.txt"), "w") as f:
            f.write(requirements)
        
        # Create tar.gz file
        with tarfile.open(model_path, "w:gz") as tar:
            tar.add(model_dir, arcname=".")
        
        print(f"SageMaker model package created: {model_path}")

def main():
    """Main function to train and save the model"""
    print("=== Simple ML Model Training ===")
    
    # Create model instance
    model = SimpleMLModel()
    
    # Generate sample data
    print("Generating sample data...")
    X, y = model.generate_sample_data(10000)
    
    # Train model
    results = model.train_model(X, y)
    
    # Save model
    model.save_model("simple_ml_model.pkl")
    
    # Create SageMaker model package
    model.create_sagemaker_model("model.tar.gz", "your-bucket", "model/model.tar.gz")
    
    # Test prediction
    print("\n=== Testing Prediction ===")
    test_features = [0.35, 0.5, 0.5, 1, 0, 0.05, 0.5, 0.2]  # Example features
    prediction = model.predict(test_features)
    print(f"Test prediction: {prediction}")
    
    print("\n=== Model Training Complete ===")

if __name__ == "__main__":
    main()
