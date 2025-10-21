#!/usr/bin/env python3
"""
EMR Setup Test Script
Tests the EMR cluster configuration and connectivity
"""

import boto3
import json
import time
import argparse
from datetime import datetime

class EMRTester:
    def __init__(self, region='us-east-1'):
        """Initialize EMR tester"""
        self.emr_client = boto3.client('emr', region_name=region)
        self.s3_client = boto3.client('s3', region_name=region)
        self.region = region
    
    def test_cluster_connectivity(self, cluster_id):
        """Test EMR cluster connectivity and status"""
        print(f"Testing cluster connectivity for {cluster_id}...")
        
        try:
            response = self.emr_client.describe_cluster(ClusterId=cluster_id)
            cluster = response['Cluster']
            
            print(f"✓ Cluster Name: {cluster['Name']}")
            print(f"✓ Status: {cluster['Status']['State']}")
            print(f"✓ Release Label: {cluster['ReleaseLabel']}")
            print(f"✓ Master Public DNS: {cluster.get('MasterPublicDnsName', 'N/A')}")
            
            # Check if cluster is running
            if cluster['Status']['State'] == 'WAITING':
                print("✓ Cluster is running and ready")
                return True
            elif cluster['Status']['State'] == 'STARTING':
                print("⚠ Cluster is starting up...")
                return False
            else:
                print(f"✗ Cluster status: {cluster['Status']['State']}")
                return False
                
        except Exception as e:
            print(f"✗ Error connecting to cluster: {str(e)}")
            return False
    
    def test_s3_connectivity(self, bucket_name):
        """Test S3 bucket connectivity"""
        print(f"Testing S3 connectivity for bucket {bucket_name}...")
        
        try:
            # Test bucket access
            response = self.s3_client.head_bucket(Bucket=bucket_name)
            print("✓ S3 bucket is accessible")
            
            # List objects in bucket
            response = self.s3_client.list_objects_v2(Bucket=bucket_name, MaxKeys=5)
            if 'Contents' in response:
                print(f"✓ Found {len(response['Contents'])} objects in bucket")
                for obj in response['Contents'][:3]:
                    print(f"  - {obj['Key']}")
            else:
                print("⚠ Bucket is empty")
            
            return True
            
        except Exception as e:
            print(f"✗ Error accessing S3 bucket: {str(e)}")
            return False
    
    def test_spark_job(self, cluster_id, script_path):
        """Test Spark job execution"""
        print(f"Testing Spark job execution...")
        
        try:
            # Create a simple test step
            step = {
                'Name': f'Test Spark Job - {datetime.now().strftime("%Y%m%d_%H%M%S")}',
                'ActionOnFailure': 'CONTINUE',
                'HadoopJarStep': {
                    'Jar': 'command-runner.jar',
                    'Args': [
                        'spark-submit',
                        '--deploy-mode', 'cluster',
                        '--class', 'org.apache.spark.examples.SparkPi',
                        '--num-executors', '1',
                        '--executor-memory', '1g',
                        '--executor-cores', '1',
                        's3://aws-logs-us-east-1/elasticmapreduce/spark/spark-examples.jar',
                        '10'
                    ]
                }
            }
            
            # Submit step
            response = self.emr_client.add_job_flow_steps(
                JobFlowId=cluster_id,
                Steps=[step]
            )
            
            step_id = response['StepIds'][0]
            print(f"✓ Test step submitted: {step_id}")
            
            # Monitor step
            return self.monitor_step(cluster_id, step_id, timeout_minutes=5)
            
        except Exception as e:
            print(f"✗ Error submitting test step: {str(e)}")
            return False
    
    def monitor_step(self, cluster_id, step_id, timeout_minutes=10):
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
                print(f"  Step status: {status}")
                
                if status == 'COMPLETED':
                    print("✓ Test step completed successfully!")
                    return True
                elif status in ['FAILED', 'CANCELLED']:
                    print(f"✗ Test step failed with status: {status}")
                    if 'FailureDetails' in response['Step']['Status']:
                        print(f"  Failure details: {response['Step']['Status']['FailureDetails']}")
                    return False
                
                time.sleep(30)
                
            except Exception as e:
                print(f"✗ Error monitoring step: {str(e)}")
                return False
        
        print("⚠ Step monitoring timed out")
        return False
    
    def test_auto_scaling(self, cluster_id):
        """Test EMR auto-scaling configuration"""
        print("Testing auto-scaling configuration...")
        
        try:
            response = self.emr_client.describe_cluster(ClusterId=cluster_id)
            cluster = response['Cluster']
            
            # Check if auto-scaling is enabled
            if 'AutoScalingRole' in cluster:
                print("✓ Auto-scaling is enabled")
                print(f"  Auto-scaling role: {cluster['AutoScalingRole']}")
                
                # Get scaling policy
                try:
                    scaling_response = self.emr_client.describe_managed_scaling_policy(
                        ClusterId=cluster_id
                    )
                    if 'ManagedScalingPolicy' in scaling_response:
                        policy = scaling_response['ManagedScalingPolicy']
                        print(f"  Min capacity: {policy['ComputeLimits']['MinimumCapacityUnits']}")
                        print(f"  Max capacity: {policy['ComputeLimits']['MaximumCapacityUnits']}")
                        return True
                except:
                    print("⚠ Auto-scaling policy not found")
                    return False
            else:
                print("⚠ Auto-scaling is not enabled")
                return False
                
        except Exception as e:
            print(f"✗ Error checking auto-scaling: {str(e)}")
            return False
    
    def test_security_groups(self, cluster_id):
        """Test security group configuration"""
        print("Testing security group configuration...")
        
        try:
            response = self.emr_client.describe_cluster(ClusterId=cluster_id)
            cluster = response['Cluster']
            
            # Get EC2 attributes
            ec2_attributes = cluster.get('Ec2InstanceAttributes', {})
            
            if 'EmrManagedMasterSecurityGroup' in ec2_attributes:
                print("✓ Master security group configured")
            
            if 'EmrManagedSlaveSecurityGroup' in ec2_attributes:
                print("✓ Worker security group configured")
            
            if 'ServiceAccessSecurityGroup' in ec2_attributes:
                print("✓ Service access security group configured")
            
            return True
            
        except Exception as e:
            print(f"✗ Error checking security groups: {str(e)}")
            return False
    
    def run_comprehensive_test(self, cluster_id, data_bucket, scripts_bucket):
        """Run comprehensive EMR setup test"""
        print("=" * 60)
        print("EMR SETUP COMPREHENSIVE TEST")
        print("=" * 60)
        
        test_results = {}
        
        # Test 1: Cluster connectivity
        test_results['cluster_connectivity'] = self.test_cluster_connectivity(cluster_id)
        
        # Test 2: S3 connectivity
        test_results['s3_data_bucket'] = self.test_s3_connectivity(data_bucket)
        test_results['s3_scripts_bucket'] = self.test_s3_connectivity(scripts_bucket)
        
        # Test 3: Security groups
        test_results['security_groups'] = self.test_security_groups(cluster_id)
        
        # Test 4: Auto-scaling
        test_results['auto_scaling'] = self.test_auto_scaling(cluster_id)
        
        # Test 5: Spark job execution
        if test_results['cluster_connectivity']:
            test_results['spark_job'] = self.test_spark_job(cluster_id, None)
        else:
            test_results['spark_job'] = False
        
        # Summary
        print("\n" + "=" * 60)
        print("TEST RESULTS SUMMARY")
        print("=" * 60)
        
        passed_tests = 0
        total_tests = len(test_results)
        
        for test_name, result in test_results.items():
            status = "✓ PASS" if result else "✗ FAIL"
            print(f"{test_name.replace('_', ' ').title()}: {status}")
            if result:
                passed_tests += 1
        
        print(f"\nOverall: {passed_tests}/{total_tests} tests passed")
        
        if passed_tests == total_tests:
            print("🎉 All tests passed! EMR setup is working correctly.")
        else:
            print("⚠ Some tests failed. Please check the configuration.")
        
        return test_results

def main():
    """Main function for EMR testing"""
    parser = argparse.ArgumentParser(description="EMR Setup Test Script")
    parser.add_argument("--cluster-id", required=True, help="EMR Cluster ID")
    parser.add_argument("--data-bucket", required=True, help="S3 Data Bucket Name")
    parser.add_argument("--scripts-bucket", required=True, help="S3 Scripts Bucket Name")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--test", choices=["connectivity", "s3", "spark", "scaling", "all"], 
                       default="all", help="Specific test to run")
    
    args = parser.parse_args()
    
    # Initialize tester
    tester = EMRTester(args.region)
    
    if args.test == "all":
        tester.run_comprehensive_test(args.cluster_id, args.data_bucket, args.scripts_bucket)
    elif args.test == "connectivity":
        tester.test_cluster_connectivity(args.cluster_id)
    elif args.test == "s3":
        tester.test_s3_connectivity(args.data_bucket)
        tester.test_s3_connectivity(args.scripts_bucket)
    elif args.test == "spark":
        tester.test_spark_job(args.cluster_id, None)
    elif args.test == "scaling":
        tester.test_auto_scaling(args.cluster_id)

if __name__ == "__main__":
    main()
