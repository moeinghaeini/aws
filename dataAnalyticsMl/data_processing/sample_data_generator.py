#!/usr/bin/env python3
"""
Sample Data Generator for Data Analytics ML Platform
Generates realistic sample data for testing the analytics platform
"""

import json
import random
import time
import boto3
from datetime import datetime, timedelta
from typing import Dict, List, Any
import argparse
import sys

class SampleDataGenerator:
    def __init__(self, stream_name: str, region: str = 'us-east-1'):
        self.stream_name = stream_name
        self.kinesis_client = boto3.client('kinesis', region_name=region)
        
        # Sample data templates
        self.event_types = ['view', 'click', 'purchase', 'signup', 'login', 'logout', 'add_to_cart', 'remove_from_cart']
        self.user_segments = ['high_value', 'medium_value', 'low_value', 'new_user']
        self.product_categories = ['electronics', 'clothing', 'books', 'home', 'sports', 'beauty', 'automotive']
        self.device_types = ['desktop', 'mobile', 'tablet']
        self.browsers = ['chrome', 'firefox', 'safari', 'edge']
        self.operating_systems = ['windows', 'macos', 'linux', 'ios', 'android']
        
        # User base for consistent data
        self.users = self._generate_user_base(1000)
    
    def _generate_user_base(self, count: int) -> List[Dict[str, Any]]:
        """Generate a base set of users for consistent data generation"""
        users = []
        for i in range(count):
            user = {
                'user_id': f'user_{i:06d}',
                'age': random.randint(18, 80),
                'income': random.randint(20000, 200000),
                'location': random.choice(['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'JP']),
                'signup_date': datetime.now() - timedelta(days=random.randint(1, 365)),
                'is_premium': random.choice([True, False]),
                'preferred_category': random.choice(self.product_categories)
            }
            users.append(user)
        return users
    
    def _generate_event(self, user: Dict[str, Any]) -> Dict[str, Any]:
        """Generate a single event for a user"""
        event_type = random.choice(self.event_types)
        timestamp = datetime.now() - timedelta(minutes=random.randint(0, 60))
        
        # Base event structure
        event = {
            'timestamp': timestamp.isoformat() + 'Z',
            'user_id': user['user_id'],
            'event_type': event_type,
            'session_id': f'session_{random.randint(100000, 999999)}',
            'device_type': random.choice(self.device_types),
            'browser': random.choice(self.browsers),
            'operating_system': random.choice(self.operating_systems),
            'location': user['location'],
            'user_age': user['age'],
            'user_income': user['income'],
            'is_premium_user': user['is_premium']
        }
        
        # Event-specific data
        if event_type == 'view':
            event.update({
                'product_id': f'prod_{random.randint(1000, 9999)}',
                'product_category': random.choice(self.product_categories),
                'page_url': f'/products/{random.randint(1000, 9999)}',
                'time_on_page': random.randint(10, 300)
            })
        
        elif event_type == 'click':
            event.update({
                'click_target': random.choice(['button', 'link', 'image', 'ad']),
                'click_position': {'x': random.randint(0, 1920), 'y': random.randint(0, 1080)},
                'page_url': f'/products/{random.randint(1000, 9999)}'
            })
        
        elif event_type == 'purchase':
            event.update({
                'product_id': f'prod_{random.randint(1000, 9999)}',
                'product_category': random.choice(self.product_categories),
                'value': round(random.uniform(10, 1000), 2),
                'quantity': random.randint(1, 5),
                'payment_method': random.choice(['credit_card', 'debit_card', 'paypal', 'apple_pay']),
                'discount_applied': random.choice([True, False]),
                'discount_amount': round(random.uniform(0, 50), 2) if random.choice([True, False]) else 0
            })
        
        elif event_type == 'add_to_cart':
            event.update({
                'product_id': f'prod_{random.randint(1000, 9999)}',
                'product_category': random.choice(self.product_categories),
                'value': round(random.uniform(5, 500), 2),
                'quantity': random.randint(1, 3)
            })
        
        elif event_type == 'signup':
            event.update({
                'signup_method': random.choice(['email', 'social_media', 'referral']),
                'newsletter_subscription': random.choice([True, False])
            })
        
        elif event_type == 'login':
            event.update({
                'login_method': random.choice(['email', 'social_media', 'sso']),
                'session_duration': random.randint(300, 3600)
            })
        
        # Add session and user behavior data
        event.update({
            'session_duration': random.randint(60, 3600),
            'page_views': random.randint(1, 20),
            'time_on_site': random.randint(60, 3600),
            'bounce_rate': random.uniform(0, 1),
            'has_previous_purchase': random.choice([True, False]),
            'days_since_last_visit': random.randint(0, 30)
        })
        
        return event
    
    def _send_to_kinesis(self, events: List[Dict[str, Any]]) -> None:
        """Send events to Kinesis stream"""
        try:
            records = []
            for event in events:
                record = {
                    'Data': json.dumps(event),
                    'PartitionKey': event['user_id']
                }
                records.append(record)
            
            # Send records in batches
            response = self.kinesis_client.put_records(
                StreamName=self.stream_name,
                Records=records
            )
            
            # Check for failed records
            failed_count = response['FailedRecordCount']
            if failed_count > 0:
                print(f"Warning: {failed_count} records failed to send")
                for i, record in enumerate(response['Records']):
                    if 'ErrorCode' in record:
                        print(f"Record {i} failed: {record['ErrorCode']} - {record['ErrorMessage']}")
            
        except Exception as e:
            print(f"Error sending to Kinesis: {str(e)}")
            raise
    
    def generate_data(self, num_events: int, batch_size: int = 10) -> None:
        """Generate and send sample data"""
        print(f"Generating {num_events} events in batches of {batch_size}")
        
        events_sent = 0
        batch_count = 0
        
        while events_sent < num_events:
            # Generate batch of events
            batch_events = []
            batch_size_actual = min(batch_size, num_events - events_sent)
            
            for _ in range(batch_size_actual):
                user = random.choice(self.users)
                event = self._generate_event(user)
                batch_events.append(event)
            
            # Send batch to Kinesis
            self._send_to_kinesis(batch_events)
            
            events_sent += batch_size_actual
            batch_count += 1
            
            print(f"Sent batch {batch_count}: {events_sent}/{num_events} events")
            
            # Small delay between batches
            time.sleep(0.1)
        
        print(f"Successfully generated and sent {events_sent} events to {self.stream_name}")
    
    def generate_continuous_data(self, duration_minutes: int, events_per_minute: int) -> None:
        """Generate continuous data for a specified duration"""
        print(f"Generating continuous data for {duration_minutes} minutes at {events_per_minute} events/minute")
        
        start_time = datetime.now()
        end_time = start_time + timedelta(minutes=duration_minutes)
        
        while datetime.now() < end_time:
            # Generate events for this minute
            events = []
            for _ in range(events_per_minute):
                user = random.choice(self.users)
                event = self._generate_event(user)
                events.append(event)
            
            # Send events
            self._send_to_kinesis(events)
            
            print(f"Sent {events_per_minute} events at {datetime.now().strftime('%H:%M:%S')}")
            
            # Wait for next minute
            time.sleep(60)
        
        print("Continuous data generation completed")

def main():
    parser = argparse.ArgumentParser(description='Generate sample data for the analytics platform')
    parser.add_argument('--stream-name', required=True, help='Kinesis stream name')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--num-events', type=int, default=1000, help='Number of events to generate')
    parser.add_argument('--batch-size', type=int, default=10, help='Batch size for sending events')
    parser.add_argument('--continuous', action='store_true', help='Generate continuous data')
    parser.add_argument('--duration', type=int, default=60, help='Duration in minutes for continuous generation')
    parser.add_argument('--events-per-minute', type=int, default=100, help='Events per minute for continuous generation')
    
    args = parser.parse_args()
    
    try:
        generator = SampleDataGenerator(args.stream_name, args.region)
        
        if args.continuous:
            generator.generate_continuous_data(args.duration, args.events_per_minute)
        else:
            generator.generate_data(args.num_events, args.batch_size)
    
    except KeyboardInterrupt:
        print("\nData generation interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
