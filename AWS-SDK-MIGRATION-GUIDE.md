# AWS SDK v2 to v3 Migration Guide

This guide helps you migrate from AWS SDK v2 to v3 in the updated AWS projects.

## Key Changes

### 1. Package Structure
**Before (v2):**
```javascript
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
```

**After (v3):**
```javascript
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const s3Client = new S3Client({});
```

### 2. Service Clients
**Before (v2):**
```javascript
const s3 = new AWS.S3({
  region: 'us-east-1',
  accessKeyId: 'your-key',
  secretAccessKey: 'your-secret'
});
```

**After (v3):**
```javascript
const s3Client = new S3Client({
  region: 'us-east-1',
  credentials: {
    accessKeyId: 'your-key',
    secretAccessKey: 'your-secret'
  }
});
```

### 3. Command Pattern
**Before (v2):**
```javascript
s3.putObject({
  Bucket: 'my-bucket',
  Key: 'my-key',
  Body: 'Hello World'
}, (err, data) => {
  if (err) console.error(err);
  else console.log(data);
});
```

**After (v3):**
```javascript
const command = new PutObjectCommand({
  Bucket: 'my-bucket',
  Key: 'my-key',
  Body: 'Hello World'
});

try {
  const response = await s3Client.send(command);
  console.log(response);
} catch (error) {
  console.error(error);
}
```

## Updated Dependencies

### Project 2 (GlobalMart E-Commerce)
```json
{
  "@aws-sdk/client-s3": "^3.709.0",
  "@aws-sdk/client-ses": "^3.709.0",
  "@aws-sdk/client-dynamodb": "^3.709.0"
}
```

### Project 5 (Repair Shop)
```json
{
  "@aws-sdk/client-s3": "^3.709.0",
  "@aws-sdk/client-ses": "^3.709.0"
}
```

## Common Service Migrations

### S3 Operations
```javascript
// v2
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

// v3
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const s3Client = new S3Client({});
```

### DynamoDB Operations
```javascript
// v2
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

// v3
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');
const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
```

### SES Operations
```javascript
// v2
const AWS = require('aws-sdk');
const ses = new AWS.SES();

// v3
const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');
const sesClient = new SESClient({});
```

## Benefits of v3

1. **Modular**: Import only the services you need
2. **Tree-shakable**: Smaller bundle sizes
3. **TypeScript**: Better type safety
4. **Performance**: Faster execution
5. **Security**: Latest security patches

## Migration Steps

1. **Update package.json**: Replace `aws-sdk` with specific client packages
2. **Update imports**: Use specific client imports
3. **Update client initialization**: Use new client constructors
4. **Update operations**: Use command pattern with async/await
5. **Test thoroughly**: Verify all functionality works correctly

## Example Migration

### Before (v2)
```javascript
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

exports.handler = async (event) => {
  const params = {
    Bucket: 'my-bucket',
    Key: 'my-key',
    Body: JSON.stringify(event)
  };
  
  return s3.putObject(params).promise();
};
```

### After (v3)
```javascript
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const s3Client = new S3Client({});

exports.handler = async (event) => {
  const command = new PutObjectCommand({
    Bucket: 'my-bucket',
    Key: 'my-key',
    Body: JSON.stringify(event)
  });
  
  return s3Client.send(command);
};
```

## Resources

- [AWS SDK v3 Migration Guide](https://docs.aws.amazon.com/sdk-for-javascript/v3/developer-guide/migrating-to-v3.html)
- [AWS SDK v3 API Reference](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/)
- [AWS SDK v3 Examples](https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/javascriptv3)
