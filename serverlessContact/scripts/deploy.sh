#!/bin/bash

# Serverless Contact Form Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"

echo -e "${GREEN}Starting Serverless Contact Form Deployment...${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed. Please install it first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Deploying Infrastructure with Terraform...${NC}"
cd infrastructure
terraform init
terraform plan
terraform apply -auto-approve

# Get outputs from Terraform
S3_BUCKET=$(terraform output -raw s3_bucket_name)
S3_WEBSITE_URL=$(terraform output -raw s3_website_url)
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)

echo -e "${YELLOW}Step 2: Uploading Contact Form to S3...${NC}"
cd ../frontend

# Update the API endpoint in the HTML file
sed -i.bak "s|https://YOUR_API_GATEWAY_URL.execute-api.us-east-1.amazonaws.com/prod/contact|${API_GATEWAY_URL}|g" index.html

# Upload to S3
aws s3 cp index.html s3://${S3_BUCKET}/index.html
aws s3 cp index.html s3://${S3_BUCKET}/error.html

echo -e "${YELLOW}Step 3: Setting up debugging scenarios...${NC}"

# Create a broken version of the contact form for debugging
cat > index_broken.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Contact Form - BROKEN VERSION</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }
        .container { background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; margin-bottom: 30px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; color: #555; }
        input, textarea, select { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 16px; box-sizing: border-box; }
        textarea { height: 120px; resize: vertical; }
        button { background-color: #007bff; color: white; padding: 12px 30px; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; width: 100%; }
        button:hover { background-color: #0056b3; }
        .status { margin-top: 20px; padding: 10px; border-radius: 4px; display: none; }
        .status.success { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .status.error { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Contact Us - BROKEN VERSION</h1>
        <p style="color: red; font-weight: bold;">This version has intentional issues for debugging practice!</p>
        
        <form id="contactForm">
            <div class="form-group">
                <label for="name">Full Name *</label>
                <input type="text" id="name" name="name" required>
            </div>
            
            <div class="form-group">
                <label for="email">Email Address *</label>
                <input type="email" id="email" name="email" required>
            </div>
            
            <div class="form-group">
                <label for="subject">Subject *</label>
                <select id="subject" name="subject" required>
                    <option value="">Select a subject</option>
                    <option value="general">General Inquiry</option>
                    <option value="support">Technical Support</option>
                    <option value="sales">Sales Question</option>
                </select>
            </div>
            
            <div class="form-group">
                <label for="message">Message *</label>
                <textarea id="message" name="message" required></textarea>
            </div>
            
            <button type="submit" id="submitBtn">Send Message</button>
        </form>
        
        <div id="status" class="status"></div>
    </div>

    <script>
        // BROKEN: Wrong API endpoint
        const API_ENDPOINT = 'https://wrong-endpoint.execute-api.us-east-1.amazonaws.com/prod/contact';
        
        const form = document.getElementById('contactForm');
        const submitBtn = document.getElementById('submitBtn');
        const status = document.getElementById('status');
        
        function showStatus(message, type) {
            status.textContent = message;
            status.className = \`status \${type}\`;
            status.style.display = 'block';
        }
        
        form.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            submitBtn.disabled = true;
            submitBtn.textContent = 'Sending...';
            
            const formData = new FormData(form);
            const data = Object.fromEntries(formData.entries());
            
            try {
                // BROKEN: Missing CORS headers, wrong endpoint
                const response = await fetch(API_ENDPOINT, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data)
                });
                
                if (!response.ok) {
                    throw new Error(\`HTTP error! status: \${response.status}\`);
                }
                
                const result = await response.json();
                showStatus('Thank you! Your message has been sent successfully.', 'success');
                form.reset();
                
            } catch (error) {
                showStatus('Sorry, there was an error sending your message. Please try again later.', 'error');
                console.error('Error:', error);
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = 'Send Message';
            }
        });
    </script>
</body>
</html>
EOF

# Upload broken version
aws s3 cp index_broken.html s3://${S3_BUCKET}/index_broken.html

echo -e "${YELLOW}Step 4: Creating debugging documentation...${NC}"

# Create debugging guide
cat > ../DEBUGGING_GUIDE.md << EOF
# Contact Form Debugging Guide

## Deployment Information
- **S3 Bucket**: ${S3_BUCKET}
- **Website URL**: http://${S3_WEBSITE_URL}
- **API Gateway URL**: ${API_GATEWAY_URL}
- **DynamoDB Table**: ${DYNAMODB_TABLE}
- **SNS Topic ARN**: ${SNS_TOPIC_ARN}

## Testing URLs
- **Working Form**: http://${S3_WEBSITE_URL}
- **Broken Form**: http://${S3_WEBSITE_URL}/index_broken.html

## Common Issues to Debug

### 1. CORS Issues
- **Symptoms**: Browser console shows CORS errors
- **Debug Steps**:
  1. Check browser developer tools console
  2. Verify API Gateway CORS configuration
  3. Check Lambda function response headers

### 2. API Gateway Issues
- **Symptoms**: 502/503 errors, timeouts
- **Debug Steps**:
  1. Check API Gateway logs
  2. Verify Lambda function integration
  3. Check Lambda function logs in CloudWatch

### 3. Lambda Function Issues
- **Symptoms**: 500 errors, function timeouts
- **Debug Steps**:
  1. Check CloudWatch logs for Lambda function
  2. Verify IAM permissions
  3. Check function environment variables

### 4. DynamoDB Issues
- **Symptoms**: Database errors, data not saved
- **Debug Steps**:
  1. Check DynamoDB table permissions
  2. Verify table exists and is accessible
  3. Check Lambda function DynamoDB permissions

### 5. SNS Issues
- **Symptoms**: No email notifications
- **Debug Steps**:
  1. Check SNS topic configuration
  2. Verify email subscription status
  3. Check Lambda function SNS permissions

## Debugging Commands

### Check Lambda Function Logs
\`\`\`bash
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/contact-form"
aws logs tail /aws/lambda/contact-form-handler --follow
\`\`\`

### Check API Gateway Logs
\`\`\`bash
aws logs describe-log-groups --log-group-name-prefix "/aws/apigateway"
\`\`\`

### Test Lambda Function Directly
\`\`\`bash
aws lambda invoke --function-name contact-form-handler --payload '{"body":"{\\"name\\":\\"Test User\\",\\"email\\":\\"test@example.com\\",\\"subject\\":\\"test\\",\\"message\\":\\"Test message\\"}"}' response.json
cat response.json
\`\`\`

### Check DynamoDB Table
\`\`\`bash
aws dynamodb scan --table-name ${DYNAMODB_TABLE}
\`\`\`

### Check SNS Topic
\`\`\`bash
aws sns list-subscriptions-by-topic --topic-arn ${SNS_TOPIC_ARN}
\`\`\`

## Expected Issues in Broken Version
1. Wrong API endpoint URL
2. Missing CORS headers
3. No error handling
4. Incorrect request format
5. Missing validation

## Fixing the Issues
1. Update API endpoint URL
2. Add proper CORS headers
3. Implement error handling
4. Fix request format
5. Add input validation
EOF

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Contact Form URL: http://${S3_WEBSITE_URL}${NC}"
echo -e "${GREEN}Broken Form URL: http://${S3_WEBSITE_URL}/index_broken.html${NC}"
echo -e "${GREEN}API Gateway URL: ${API_GATEWAY_URL}${NC}"
echo ""
echo -e "${YELLOW}Debugging Information:${NC}"
echo -e "S3 Bucket: ${S3_BUCKET}"
echo -e "DynamoDB Table: ${DYNAMODB_TABLE}"
echo -e "SNS Topic ARN: ${SNS_TOPIC_ARN}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test the working contact form"
echo "2. Test the broken contact form and identify issues"
echo "3. Use the debugging guide to troubleshoot problems"
echo "4. Check CloudWatch logs for detailed error information"
echo "5. Fix the issues in the broken version"
echo ""
echo -e "${YELLOW}Common Issues to Look For:${NC}"
echo "- CORS configuration problems"
echo "- API Gateway integration issues"
echo "- Lambda function errors"
echo "- DynamoDB permission problems"
echo "- SNS notification failures"
echo "- Input validation issues"
