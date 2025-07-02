#!/bin/bash

# Set these via EC2 instance environment variables or pass them
S3_BUCKET_NAME="${S3_BUCKET_NAME:-techeazy-app-logs-dev}"
STAGE="${STAGE:-Dev}"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Upload system logs
aws s3 cp /var/log/cloud-init.log "s3://${S3_BUCKET_NAME}/${STAGE}/system_logs/cloud-init-${INSTANCE_ID}-${TIMESTAMP}.log"

# Upload app logs if available
if [ -d /app/logs ]; then
  aws s3 cp /app/logs "s3://${S3_BUCKET_NAME}/${STAGE}/app_logs/" --recursive
fi
