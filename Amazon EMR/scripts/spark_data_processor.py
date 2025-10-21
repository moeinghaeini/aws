#!/usr/bin/env python3
"""
Spark Data Processing Script for Amazon EMR
Processes data from S3 and performs analytics operations
"""

import sys
import argparse
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import boto3
import json
from datetime import datetime

def create_spark_session(app_name="EMR Data Processor"):
    """Create and configure Spark session"""
    spark = SparkSession.builder \
        .appName(app_name) \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
        .getOrCreate()
    
    # Set log level to reduce verbosity
    spark.sparkContext.setLogLevel("WARN")
    
    return spark

def process_sales_data(spark, input_path, output_path):
    """Process sales data and generate analytics"""
    print(f"Processing sales data from: {input_path}")
    
    # Define schema for sales data
    sales_schema = StructType([
        StructField("order_id", StringType(), True),
        StructField("customer_id", StringType(), True),
        StructField("product_id", StringType(), True),
        StructField("product_name", StringType(), True),
        StructField("category", StringType(), True),
        StructField("quantity", IntegerType(), True),
        StructField("unit_price", DoubleType(), True),
        StructField("order_date", TimestampType(), True),
        StructField("region", StringType(), True),
        StructField("sales_rep", StringType(), True)
    ])
    
    try:
        # Read data from S3
        df = spark.read \
            .option("header", "true") \
            .option("inferSchema", "false") \
            .schema(sales_schema) \
            .csv(input_path)
        
        print(f"Loaded {df.count()} records")
        
        # Data quality checks
        print("Performing data quality checks...")
        
        # Check for null values
        null_counts = df.select([count(when(col(c).isNull(), c)).alias(c) for c in df.columns]).collect()[0]
        print("Null value counts:", null_counts.asDict())
        
        # Remove rows with null critical fields
        df_clean = df.filter(
            col("order_id").isNotNull() & 
            col("customer_id").isNotNull() & 
            col("quantity").isNotNull() & 
            col("unit_price").isNotNull()
        )
        
        print(f"Records after cleaning: {df_clean.count()}")
        
        # Calculate total sales
        df_with_total = df_clean.withColumn("total_sales", col("quantity") * col("unit_price"))
        
        # Analytics 1: Sales by Category
        category_sales = df_with_total.groupBy("category") \
            .agg(
                sum("total_sales").alias("total_revenue"),
                count("order_id").alias("order_count"),
                avg("total_sales").alias("avg_order_value"),
                sum("quantity").alias("total_quantity")
            ) \
            .orderBy(desc("total_revenue"))
        
        # Analytics 2: Sales by Region
        region_sales = df_with_total.groupBy("region") \
            .agg(
                sum("total_sales").alias("total_revenue"),
                count("order_id").alias("order_count"),
                countDistinct("customer_id").alias("unique_customers")
            ) \
            .orderBy(desc("total_revenue"))
        
        # Analytics 3: Top Customers
        top_customers = df_with_total.groupBy("customer_id") \
            .agg(
                sum("total_sales").alias("total_spent"),
                count("order_id").alias("order_count"),
                countDistinct("product_id").alias("products_purchased")
            ) \
            .orderBy(desc("total_spent")) \
            .limit(10)
        
        # Analytics 4: Monthly Sales Trend
        monthly_trend = df_with_total.withColumn("year_month", date_format("order_date", "yyyy-MM")) \
            .groupBy("year_month") \
            .agg(
                sum("total_sales").alias("monthly_revenue"),
                count("order_id").alias("monthly_orders"),
                countDistinct("customer_id").alias("monthly_customers")
            ) \
            .orderBy("year_month")
        
        # Write results to S3
        print("Writing analytics results to S3...")
        
        # Write category sales
        category_sales.write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(f"{output_path}/analytics/category_sales")
        
        # Write region sales
        region_sales.write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(f"{output_path}/analytics/region_sales")
        
        # Write top customers
        top_customers.write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(f"{output_path}/analytics/top_customers")
        
        # Write monthly trend
        monthly_trend.write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(f"{output_path}/analytics/monthly_trend")
        
        # Generate summary report
        summary_stats = {
            "total_orders": df_clean.count(),
            "total_revenue": df_with_total.agg(sum("total_sales")).collect()[0][0],
            "unique_customers": df_clean.select("customer_id").distinct().count(),
            "unique_products": df_clean.select("product_id").distinct().count(),
            "date_range": {
                "start": df_clean.agg(min("order_date")).collect()[0][0],
                "end": df_clean.agg(max("order_date")).collect()[0][0]
            },
            "processing_timestamp": datetime.now().isoformat()
        }
        
        # Write summary to S3
        summary_df = spark.createDataFrame([summary_stats], StructType([
            StructField("total_orders", LongType()),
            StructField("total_revenue", DoubleType()),
            StructField("unique_customers", LongType()),
            StructField("unique_products", LongType()),
            StructField("date_range", StringType()),
            StructField("processing_timestamp", StringType())
        ]))
        
        summary_df.write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(f"{output_path}/summary/processing_summary")
        
        print("Data processing completed successfully!")
        print(f"Summary: {summary_stats}")
        
        return True
        
    except Exception as e:
        print(f"Error processing data: {str(e)}")
        return False

def process_log_data(spark, input_path, output_path):
    """Process log data for web analytics"""
    print(f"Processing log data from: {input_path}")
    
    try:
        # Read log data (assuming JSON format)
        df = spark.read \
            .option("multiline", "true") \
            .json(input_path)
        
        print(f"Loaded {df.count()} log records")
        
        # Parse timestamp and extract date components
        df_parsed = df.withColumn("timestamp", to_timestamp(col("timestamp"))) \
            .withColumn("date", to_date(col("timestamp"))) \
            .withColumn("hour", hour(col("timestamp")))
        
        # Web analytics
        page_views = df_parsed.groupBy("page") \
            .agg(
                count("*").alias("page_views"),
                countDistinct("user_id").alias("unique_visitors")
            ) \
            .orderBy(desc("page_views"))
        
        hourly_traffic = df_parsed.groupBy("hour") \
            .agg(
                count("*").alias("requests"),
                countDistinct("user_id").alias("unique_users")
            ) \
            .orderBy("hour")
        
        # Write results
        page_views.write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(f"{output_path}/analytics/page_views")
        
        hourly_traffic.write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(f"{output_path}/analytics/hourly_traffic")
        
        print("Log data processing completed!")
        return True
        
    except Exception as e:
        print(f"Error processing log data: {str(e)}")
        return False

def main():
    """Main function to orchestrate data processing"""
    parser = argparse.ArgumentParser(description="EMR Spark Data Processor")
    parser.add_argument("--input-path", required=True, help="S3 input path for data")
    parser.add_argument("--output-path", required=True, help="S3 output path for results")
    parser.add_argument("--data-type", choices=["sales", "logs"], default="sales", 
                       help="Type of data to process")
    parser.add_argument("--app-name", default="EMR Data Processor", 
                       help="Spark application name")
    
    args = parser.parse_args()
    
    print(f"Starting EMR Data Processing Job")
    print(f"Input Path: {args.input_path}")
    print(f"Output Path: {args.output_path}")
    print(f"Data Type: {args.data_type}")
    
    # Create Spark session
    spark = create_spark_session(args.app_name)
    
    try:
        # Process data based on type
        if args.data_type == "sales":
            success = process_sales_data(spark, args.input_path, args.output_path)
        elif args.data_type == "logs":
            success = process_log_data(spark, args.input_path, args.output_path)
        else:
            print(f"Unknown data type: {args.data_type}")
            success = False
        
        if success:
            print("Data processing completed successfully!")
        else:
            print("Data processing failed!")
            sys.exit(1)
            
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        sys.exit(1)
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
