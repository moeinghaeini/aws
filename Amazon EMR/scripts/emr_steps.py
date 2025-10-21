#!/usr/bin/env python3
"""
EMR Steps Management Script
Provides three methods to trigger EMR jobs as mentioned in the tutorial
"""

import boto3
import json
import time
import argparse
from datetime import datetime

class EMRStepsManager:
    def __init__(self, region='us-east-1'):
        """Initialize EMR client"""
        self.emr_client = boto3.client('emr', region_name=region)
        self.region = region
    
    def create_spark_step(self, cluster_id, script_s3_path, args=None):
        """Create a Spark step for EMR cluster"""
        step_args = [
            "spark-submit",
            "--deploy-mode", "cluster",
            "--executor-memory", "2g",
            "--executor-cores", "2",
            "--num-executors", "2"
        ]
        
        if args:
            step_args.extend(["--class", "org.apache.spark.examples.SparkPi"])
            step_args.append(script_s3_path)
            step_args.extend(args)
        else:
            step_args.append(script_s3_path)
        
        step = {
            'Name': f'Spark Data Processing - {datetime.now().strftime("%Y%m%d_%H%M%S")}',
            'ActionOnFailure': 'CONTINUE',
            'HadoopJarStep': {
                'Jar': 'command-runner.jar',
                'Args': step_args
            }
        }
        
        return step
    
    def create_python_step(self, cluster_id, script_s3_path, args=None):
        """Create a Python step for EMR cluster"""
        step_args = ["python3", script_s3_path]
        
        if args:
            step_args.extend(args)
        
        step = {
            'Name': f'Python Data Processing - {datetime.now().strftime("%Y%m%d_%H%M%S")}',
            'ActionOnFailure': 'CONTINUE',
            'HadoopJarStep': {
                'Jar': 'command-runner.jar',
                'Args': step_args
            }
        }
        
        return step
    
    def create_hive_step(self, cluster_id, hive_script_s3_path):
        """Create a Hive step for EMR cluster"""
        step = {
            'Name': f'Hive Data Processing - {datetime.now().strftime("%Y%m%d_%H%M%S")}',
            'ActionOnFailure': 'CONTINUE',
            'HadoopJarStep': {
                'Jar': 'command-runner.jar',
                'Args': [
                    'hive-script',
                    '--run-hive-script',
                    '--args',
                    '-f', hive_script_s3_path
                ]
            }
        }
        
        return step
    
    def submit_step(self, cluster_id, step):
        """Submit a step to EMR cluster"""
        try:
            response = self.emr_client.add_job_flow_steps(
                JobFlowId=cluster_id,
                Steps=[step]
            )
            
            step_id = response['StepIds'][0]
            print(f"Step submitted successfully. Step ID: {step_id}")
            return step_id
            
        except Exception as e:
            print(f"Error submitting step: {str(e)}")
            return None
    
    def monitor_step(self, cluster_id, step_id, timeout_minutes=30):
        """Monitor step execution"""
        print(f"Monitoring step {step_id}...")
        
        start_time = time.time()
        timeout_seconds = timeout_minutes * 60
        
        while time.time() - start_time < timeout_seconds:
            try:
                response = self.emr_client.describe_step(
                    ClusterId=cluster_id,
                    StepId=step_id
                )
                
                status = response['Step']['Status']['State']
                print(f"Step status: {status}")
                
                if status in ['COMPLETED', 'FAILED', 'CANCELLED']:
                    if status == 'COMPLETED':
                        print("Step completed successfully!")
                    else:
                        print(f"Step failed with status: {status}")
                        if 'FailureDetails' in response['Step']['Status']:
                            print(f"Failure details: {response['Step']['Status']['FailureDetails']}")
                    return status
                
                time.sleep(30)  # Check every 30 seconds
                
            except Exception as e:
                print(f"Error monitoring step: {str(e)}")
                return 'ERROR'
        
        print("Step monitoring timed out")
        return 'TIMEOUT'
    
    def list_steps(self, cluster_id):
        """List all steps for a cluster"""
        try:
            response = self.emr_client.list_steps(ClusterId=cluster_id)
            
            print(f"Steps for cluster {cluster_id}:")
            for step in response['Steps']:
                print(f"  Step ID: {step['Id']}")
                print(f"  Name: {step['Name']}")
                print(f"  Status: {step['Status']['State']}")
                print(f"  Created: {step['Status']['Timeline']['CreationDateTime']}")
                print("---")
                
        except Exception as e:
            print(f"Error listing steps: {str(e)}")
    
    def get_cluster_info(self, cluster_id):
        """Get cluster information"""
        try:
            response = self.emr_client.describe_cluster(ClusterId=cluster_id)
            cluster = response['Cluster']
            
            print(f"Cluster ID: {cluster['Id']}")
            print(f"Name: {cluster['Name']}")
            print(f"Status: {cluster['Status']['State']}")
            print(f"Release Label: {cluster['ReleaseLabel']}")
            print(f"Master Public DNS: {cluster.get('MasterPublicDnsName', 'N/A')}")
            print(f"Created: {cluster['Status']['Timeline']['CreationDateTime']}")
            
            return cluster
            
        except Exception as e:
            print(f"Error getting cluster info: {str(e)}")
            return None

def main():
    """Main function for EMR Steps management"""
    parser = argparse.ArgumentParser(description="EMR Steps Management")
    parser.add_argument("--cluster-id", required=True, help="EMR Cluster ID")
    parser.add_argument("--action", choices=["submit-spark", "submit-python", "submit-hive", 
                                           "monitor", "list", "info"], required=True,
                       help="Action to perform")
    parser.add_argument("--script-path", help="S3 path to script")
    parser.add_argument("--step-id", help="Step ID for monitoring")
    parser.add_argument("--args", nargs="*", help="Arguments for the script")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--timeout", type=int, default=30, help="Timeout in minutes")
    
    args = parser.parse_args()
    
    # Initialize EMR manager
    emr_manager = EMRStepsManager(args.region)
    
    if args.action == "submit-spark":
        if not args.script_path:
            print("Error: --script-path is required for submit-spark")
            return
        
        step = emr_manager.create_spark_step(args.cluster_id, args.script_path, args.args)
        step_id = emr_manager.submit_step(args.cluster_id, step)
        
        if step_id:
            print(f"Spark step submitted: {step_id}")
    
    elif args.action == "submit-python":
        if not args.script_path:
            print("Error: --script-path is required for submit-python")
            return
        
        step = emr_manager.create_python_step(args.cluster_id, args.script_path, args.args)
        step_id = emr_manager.submit_step(args.cluster_id, step)
        
        if step_id:
            print(f"Python step submitted: {step_id}")
    
    elif args.action == "submit-hive":
        if not args.script_path:
            print("Error: --script-path is required for submit-hive")
            return
        
        step = emr_manager.create_hive_step(args.cluster_id, args.script_path)
        step_id = emr_manager.submit_step(args.cluster_id, step)
        
        if step_id:
            print(f"Hive step submitted: {step_id}")
    
    elif args.action == "monitor":
        if not args.step_id:
            print("Error: --step-id is required for monitor")
            return
        
        status = emr_manager.monitor_step(args.cluster_id, args.step_id, args.timeout)
        print(f"Final step status: {status}")
    
    elif args.action == "list":
        emr_manager.list_steps(args.cluster_id)
    
    elif args.action == "info":
        emr_manager.get_cluster_info(args.cluster_id)

if __name__ == "__main__":
    main()
