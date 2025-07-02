#!/bin/bash
echo "🔄 Uploading logs to S3..."

aws s3 cp /var/log/cloud-init.log s3://${S3_BUCKET_NAME}/ec2-logs/
aws s3 cp /home/ubuntu/app/logs/app.log s3://${S3_BUCKET_NAME}/app/logs/

echo "✅ Logs uploaded successfully"
