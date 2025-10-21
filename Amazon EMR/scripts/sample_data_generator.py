#!/usr/bin/env python3
"""
Sample Data Generator for EMR Testing
Generates synthetic sales and log data for testing the EMR cluster
"""

import json
import random
import csv
from datetime import datetime, timedelta
import boto3
import argparse
from faker import Faker

fake = Faker()

# Sample data configurations
PRODUCTS = [
    {"id": "P001", "name": "Laptop Pro", "category": "Electronics", "base_price": 1299.99},
    {"id": "P002", "name": "Wireless Mouse", "category": "Electronics", "base_price": 29.99},
    {"id": "P003", "name": "Office Chair", "category": "Furniture", "base_price": 199.99},
    {"id": "P004", "name": "Coffee Maker", "category": "Appliances", "base_price": 89.99},
    {"id": "P005", "name": "Running Shoes", "category": "Sports", "base_price": 129.99},
    {"id": "P006", "name": "Backpack", "category": "Accessories", "base_price": 49.99},
    {"id": "P007", "name": "Smartphone", "category": "Electronics", "base_price": 699.99},
    {"id": "P008", "name": "Desk Lamp", "category": "Furniture", "base_price": 39.99},
    {"id": "P009", "name": "Water Bottle", "category": "Sports", "base_price": 19.99},
    {"id": "P010", "name": "Bluetooth Speaker", "category": "Electronics", "base_price": 79.99}
]

REGIONS = ["North", "South", "East", "West", "Central"]
SALES_REPS = ["Alice Johnson", "Bob Smith", "Carol Davis", "David Wilson", "Eva Brown"]

def generate_sales_data(num_records, start_date, end_date):
    """Generate synthetic sales data"""
    sales_data = []
    
    for i in range(num_records):
        # Random date between start and end
        random_days = random.randint(0, (end_date - start_date).days)
        order_date = start_date + timedelta(days=random_days)
        
        # Random product
        product = random.choice(PRODUCTS)
        
        # Random customer
        customer_id = f"C{random.randint(1000, 9999)}"
        
        # Random quantity and price variation
        quantity = random.randint(1, 5)
        price_variation = random.uniform(0.8, 1.2)
        unit_price = round(product["base_price"] * price_variation, 2)
        
        # Random region and sales rep
        region = random.choice(REGIONS)
        sales_rep = random.choice(SALES_REPS)
        
        sales_record = {
            "order_id": f"ORD{random.randint(10000, 99999)}",
            "customer_id": customer_id,
            "product_id": product["id"],
            "product_name": product["name"],
            "category": product["category"],
            "quantity": quantity,
            "unit_price": unit_price,
            "order_date": order_date.strftime("%Y-%m-%d %H:%M:%S"),
            "region": region,
            "sales_rep": sales_rep
        }
        
        sales_data.append(sales_record)
    
    return sales_data

def generate_log_data(num_records, start_date, end_date):
    """Generate synthetic web log data"""
    log_data = []
    
    pages = [
        "/home", "/products", "/about", "/contact", "/cart", 
        "/checkout", "/login", "/profile", "/search", "/help"
    ]
    
    user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    ]
    
    for i in range(num_records):
        # Random timestamp
        random_days = random.randint(0, (end_date - start_date).days)
        random_hours = random.randint(0, 23)
        random_minutes = random.randint(0, 59)
        random_seconds = random.randint(0, 59)
        
        timestamp = start_date + timedelta(
            days=random_days, 
            hours=random_hours, 
            minutes=random_minutes, 
            seconds=random_seconds
        )
        
        log_record = {
            "timestamp": timestamp.isoformat(),
            "user_id": f"U{random.randint(1000, 9999)}",
            "session_id": f"S{random.randint(10000, 99999)}",
            "page": random.choice(pages),
            "method": random.choice(["GET", "POST", "PUT", "DELETE"]),
            "status_code": random.choice([200, 200, 200, 404, 500]),  # Weighted towards 200
            "response_time": random.randint(50, 2000),
            "user_agent": random.choice(user_agents),
            "ip_address": fake.ipv4(),
            "referrer": random.choice(["google.com", "bing.com", "direct", "facebook.com", "twitter.com"])
        }
        
        log_data.append(log_record)
    
    return log_data

def upload_to_s3(data, bucket_name, key_prefix, file_format="csv"):
    """Upload data to S3"""
    s3_client = boto3.client('s3')
    
    if file_format == "csv":
        # Convert to CSV format
        if not data:
            return
        
        # Get fieldnames from first record
        fieldnames = data[0].keys()
        
        # Create CSV content
        csv_content = []
        csv_content.append(",".join(fieldnames))  # Header
        
        for record in data:
            row = []
            for field in fieldnames:
                value = record[field]
                # Escape commas and quotes in CSV
                if isinstance(value, str) and ("," in value or '"' in value):
                    value = f'"{value.replace('"', '""')}"'
                row.append(str(value))
            csv_content.append(",".join(row))
        
        csv_data = "\n".join(csv_content)
        
    elif file_format == "json":
        # Convert to JSON format
        json_data = json.dumps(data, indent=2)
    
    # Upload to S3
    try:
        if file_format == "csv":
            s3_client.put_object(
                Bucket=bucket_name,
                Key=key_prefix,
                Body=csv_data.encode('utf-8'),
                ContentType='text/csv'
            )
        elif file_format == "json":
            s3_client.put_object(
                Bucket=bucket_name,
                Key=key_prefix,
                Body=json_data.encode('utf-8'),
                ContentType='application/json'
            )
        
        print(f"Successfully uploaded {len(data)} records to s3://{bucket_name}/{key_prefix}")
        
    except Exception as e:
        print(f"Error uploading to S3: {str(e)}")

def main():
    """Main function to generate and upload sample data"""
    parser = argparse.ArgumentParser(description="Generate sample data for EMR testing")
    parser.add_argument("--bucket-name", required=True, help="S3 bucket name")
    parser.add_argument("--data-type", choices=["sales", "logs", "both"], default="both",
                       help="Type of data to generate")
    parser.add_argument("--num-records", type=int, default=1000, 
                       help="Number of records to generate")
    parser.add_argument("--start-date", default="2024-01-01", 
                       help="Start date for data generation (YYYY-MM-DD)")
    parser.add_argument("--end-date", default="2024-12-31", 
                       help="End date for data generation (YYYY-MM-DD)")
    parser.add_argument("--format", choices=["csv", "json"], default="csv",
                       help="Output format")
    
    args = parser.parse_args()
    
    # Parse dates
    start_date = datetime.strptime(args.start_date, "%Y-%m-%d")
    end_date = datetime.strptime(args.end_date, "%Y-%m-%d")
    
    print(f"Generating {args.num_records} {args.data_type} records")
    print(f"Date range: {args.start_date} to {args.end_date}")
    print(f"Output format: {args.format}")
    
    # Generate sales data
    if args.data_type in ["sales", "both"]:
        print("Generating sales data...")
        sales_data = generate_sales_data(args.num_records, start_date, end_date)
        
        # Upload sales data
        sales_key = f"raw-data/sales/sales_data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{args.format}"
        upload_to_s3(sales_data, args.bucket_name, sales_key, args.format)
    
    # Generate log data
    if args.data_type in ["logs", "both"]:
        print("Generating log data...")
        log_data = generate_log_data(args.num_records, start_date, end_date)
        
        # Upload log data
        log_key = f"raw-data/logs/web_logs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{args.format}"
        upload_to_s3(log_data, args.bucket_name, log_key, args.format)
    
    print("Sample data generation completed!")

if __name__ == "__main__":
    main()
