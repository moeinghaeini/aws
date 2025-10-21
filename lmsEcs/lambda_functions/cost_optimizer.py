import boto3
import json
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to analyze costs and provide optimization recommendations
    """
    try:
        # Initialize clients
        ce_client = boto3.client('ce')
        sns_client = boto3.client('sns')
        
        # Get environment variables
        sns_topic_arn = os.environ['SNS_TOPIC_ARN']
        
        # Get cost data for the last 30 days
        end_date = datetime.now().strftime('%Y-%m-%d')
        start_date = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
        
        # Get cost and usage data
        cost_data = get_cost_data(ce_client, start_date, end_date)
        
        # Get rightsizing recommendations
        rightsizing_recommendations = get_rightsizing_recommendations(ce_client)
        
        # Get reservation recommendations
        reservation_recommendations = get_reservation_recommendations(ce_client)
        
        # Analyze and generate recommendations
        recommendations = analyze_costs(cost_data, rightsizing_recommendations, reservation_recommendations)
        
        # Send recommendations via SNS
        if recommendations:
            send_recommendations(sns_client, sns_topic_arn, recommendations)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cost optimization analysis completed',
                'recommendations': len(recommendations)
            })
        }
        
    except Exception as e:
        logger.error(f"Error in cost optimization: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def get_cost_data(ce_client, start_date, end_date):
    """
    Get cost and usage data from Cost Explorer
    """
    try:
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date,
                'End': end_date
            },
            Granularity='DAILY',
            Metrics=['BlendedCost', 'UsageQuantity'],
            GroupBy=[
                {
                    'Type': 'DIMENSION',
                    'Key': 'SERVICE'
                }
            ]
        )
        
        return response['ResultsByTime']
        
    except Exception as e:
        logger.error(f"Error getting cost data: {str(e)}")
        return []

def get_rightsizing_recommendations(ce_client):
    """
    Get rightsizing recommendations from Cost Explorer
    """
    try:
        response = ce_client.get_rightsizing_recommendation(
            Service='Amazon Elastic Compute Cloud - Compute'
        )
        
        return response['RightsizingRecommendations']
        
    except Exception as e:
        logger.error(f"Error getting rightsizing recommendations: {str(e)}")
        return []

def get_reservation_recommendations(ce_client):
    """
    Get reservation purchase recommendations
    """
    try:
        response = ce_client.get_reservation_purchase_recommendation(
            Service='Amazon Elastic Compute Cloud - Compute',
            LookbackPeriodInDays=30
        )
        
        return response['Recommendations']
        
    except Exception as e:
        logger.error(f"Error getting reservation recommendations: {str(e)}")
        return []

def analyze_costs(cost_data, rightsizing_recommendations, reservation_recommendations):
    """
    Analyze cost data and generate recommendations
    """
    recommendations = []
    
    # Analyze daily costs
    total_cost = 0
    for day_data in cost_data:
        for group in day_data['Groups']:
            total_cost += float(group['Metrics']['BlendedCost']['Amount'])
    
    # Add rightsizing recommendations
    for recommendation in rightsizing_recommendations:
        if recommendation['RightsizingType'] == 'Modify':
            recommendations.append({
                'type': 'rightsizing',
                'resource': recommendation['CurrentInstance']['ResourceId'],
                'current_type': recommendation['CurrentInstance']['InstanceType'],
                'recommended_type': recommendation['TargetInstances'][0]['InstanceType'],
                'savings': recommendation['EstimatedMonthlySavings']
            })
    
    # Add reservation recommendations
    for recommendation in reservation_recommendations:
        recommendations.append({
            'type': 'reservation',
            'instance_type': recommendation['InstanceType'],
            'term': recommendation['TermInYears'],
            'payment_option': recommendation['PaymentOption'],
            'savings': recommendation['EstimatedMonthlySavings']
        })
    
    return recommendations

def send_recommendations(sns_client, topic_arn, recommendations):
    """
    Send cost optimization recommendations via SNS
    """
    try:
        message = {
            'subject': 'AWS Cost Optimization Recommendations',
            'body': json.dumps(recommendations, indent=2)
        }
        
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=message['subject'],
            Message=message['body']
        )
        
        logger.info(f"Sent {len(recommendations)} recommendations via SNS")
        
    except Exception as e:
        logger.error(f"Error sending recommendations: {str(e)}")
