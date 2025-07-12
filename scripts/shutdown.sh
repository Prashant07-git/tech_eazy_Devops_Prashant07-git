#!/bin/bash

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BUCKET_NAME="techeazy-app-logs-dev"

# Save EC2 system logs
sudo journalctl > /home/ubuntu/ec2-system.log
sudo dmesg > /home/ubuntu/ec2-dmesg.log

# Upload EC2 system logs
aws s3 cp /home/ubuntu/ec2-system.log s3://$BUCKET_NAME/system-logs/$TIMESTAMP-ec2-system.log
aws s3 cp /home/ubuntu/ec2-dmesg.log s3://$BUCKET_NAME/system-logs/$TIMESTAMP-dmesg.log

# Upload application log
aws s3 cp /home/ubuntu/techeazy-devops/app.log s3://$BUCKET_NAME/app-logs/$TIMESTAMP-app.log
