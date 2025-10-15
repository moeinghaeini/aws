import boto3
import json
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to create cross-region RDS snapshots for disaster recovery
    """
    try:
        # Get environment variables
        source_region = os.environ['SOURCE_REGION']
        target_region = os.environ['TARGET_REGION']
        db_instance_identifier = os.environ['DB_INSTANCE_IDENTIFIER']
        
        # Initialize RDS clients
        source_rds = boto3.client('rds', region_name=source_region)
        target_rds = boto3.client('rds', region_name=target_region)
        
        # Create snapshot in source region
        snapshot_id = f"{db_instance_identifier}-dr-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        
        logger.info(f"Creating snapshot {snapshot_id} in {source_region}")
        
        response = source_rds.create_db_snapshot(
            DBSnapshotIdentifier=snapshot_id,
            DBInstanceIdentifier=db_instance_identifier,
            Tags=[
                {
                    'Key': 'Purpose',
                    'Value': 'DisasterRecovery'
                },
                {
                    'Key': 'CreatedBy',
                    'Value': 'Lambda'
                }
            ]
        )
        
        # Wait for snapshot to be available
        waiter = source_rds.get_waiter('db_snapshot_completed')
        waiter.wait(
            DBSnapshotIdentifier=snapshot_id,
            WaiterConfig={
                'Delay': 60,
                'MaxAttempts': 60
            }
        )
        
        logger.info(f"Snapshot {snapshot_id} completed in {source_region}")
        
        # Copy snapshot to target region
        target_snapshot_id = f"{snapshot_id}-{target_region}"
        
        logger.info(f"Copying snapshot to {target_region}")
        
        target_rds.copy_db_snapshot(
            SourceDBSnapshotIdentifier=f"arn:aws:rds:{source_region}:{context.invoked_function_arn.split(':')[4]}:snapshot:{snapshot_id}",
            TargetDBSnapshotIdentifier=target_snapshot_id,
            SourceRegion=source_region,
            Tags=[
                {
                    'Key': 'Purpose',
                    'Value': 'DisasterRecovery'
                },
                {
                    'Key': 'SourceRegion',
                    'Value': source_region
                }
            ]
        )
        
        # Clean up old snapshots (keep last 7 days)
        cleanup_old_snapshots(target_rds, db_instance_identifier, days_to_keep=7)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cross-region backup completed successfully',
                'sourceSnapshot': snapshot_id,
                'targetSnapshot': target_snapshot_id
            })
        }
        
    except Exception as e:
        logger.error(f"Error in cross-region backup: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def cleanup_old_snapshots(rds_client, db_identifier, days_to_keep=7):
    """
    Clean up old snapshots older than specified days
    """
    try:
        cutoff_date = datetime.now() - timedelta(days=days_to_keep)
        
        # Get all snapshots
        response = rds_client.describe_db_snapshots(
            DBInstanceIdentifier=db_identifier,
            SnapshotType='manual'
        )
        
        for snapshot in response['DBSnapshots']:
            snapshot_date = snapshot['SnapshotCreateTime'].replace(tzinfo=None)
            
            if snapshot_date < cutoff_date and 'dr-' in snapshot['DBSnapshotIdentifier']:
                logger.info(f"Deleting old snapshot: {snapshot['DBSnapshotIdentifier']}")
                rds_client.delete_db_snapshot(
                    DBSnapshotIdentifier=snapshot['DBSnapshotIdentifier']
                )
                
    except Exception as e:
        logger.error(f"Error cleaning up old snapshots: {str(e)}")
