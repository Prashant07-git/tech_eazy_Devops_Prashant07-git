#!/bin/bash

LOG_FILE="deployment_$(date +'%Y-%m-%d_%H-%M-%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

set -e

echo "🚀 Script started"

STAGE=$1
if [ -z "$STAGE" ]; then
  echo "❌ Please provide stage name like: Dev or Prod"
  exit 1
fi

CONFIG_FILE="Config/${STAGE,,}_config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"
echo "✅ Loaded configuration: KEY_NAME=$KEY_NAME, PEM_FILE=$PEM_FILE"

SG_NAME="${STAGE,,}-ec2-sg"

echo "🔒 Checking for existing security group..."
EXISTING_SG_ID=$(aws ec2 describe-security-groups --group-names "$SG_NAME" --region "$REGION" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)

if [ "$EXISTING_SG_ID" == "None" ] || [ -z "$EXISTING_SG_ID" ]; then
  echo "🔒 Creating new security group: $SG_NAME"
  SG_ID=$(aws ec2 create-security-group --group-name "$SG_NAME" --description "Security group for $STAGE stage" --region "$REGION" --query 'GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port "$APP_PORT" --cidr 0.0.0.0/0 --region "$REGION"
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$REGION"
else
  echo "✅ Security group already exists: $EXISTING_SG_ID"
  SG_ID=$EXISTING_SG_ID
fi

echo "🪣 Checking S3 bucket: $S3_BUCKET ..."
if ! aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  echo "🪣 Creating S3 bucket: $S3_BUCKET"
  aws s3api create-bucket \
    --bucket "$S3_BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
else
  echo "✅ S3 bucket already exists: $S3_BUCKET"
fi

echo "♻️ Applying lifecycle rule to delete logs older than 7 days..."
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$S3_BUCKET" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "DeleteOldLogs",
        "Prefix": "",
        "Status": "Enabled",
        "Expiration": { "Days": 7 }
      }
    ]
  }'


echo "🚀 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --region "$REGION" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --iam-instance-profile Name=EC2S3LogUploader \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${STAGE}-Server}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

if [ -z "$INSTANCE_ID" ]; then
  echo "❌ Failed to launch instance. Check key pair and configuration."
  exit 1
fi

echo "🆔 Instance ID: $INSTANCE_ID"

echo "⏳ Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "🌐 Fetching public IP..."
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "🌍 Public IP: $PUBLIC_IP"

echo "⏳ Waiting for SSH to become available..."
until ssh -o StrictHostKeyChecking=no -i "$PEM_FILE" ubuntu@$PUBLIC_IP 'echo SSH is ready' >/dev/null 2>&1; do
  sleep 5
done
echo "✅ SSH is ready"

echo "📦 Installing Java and deploying app..."
ssh -o StrictHostKeyChecking=no -i "$PEM_FILE" ubuntu@$PUBLIC_IP <<EOF
  sudo apt update -y
  sudo apt install -y wget apt-transport-https gnupg curl

  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /usr/share/keyrings/adoptium-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/adoptium-archive-keyring.gpg] https://packages.adoptium.net/artifactory/deb jammy main" | sudo tee /etc/apt/sources.list.d/adoptium.list
  sudo apt update
  sudo apt install -y temurin-21-jdk awscli

  git clone "$GIT_REPO"
  cd techeazy-devops
  chmod +x mvnw
  ./mvnw clean package -DskipTests

  sudo nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar > app.log 2>&1 &
EOF

echo "📥 Copying shutdown script to EC2..."
scp -o StrictHostKeyChecking=no -i "$PEM_FILE" scripts/shutdown.sh ubuntu@$PUBLIC_IP:/home/ubuntu/

echo "⚙️ Setting shutdown script and cronjob..."
ssh -o StrictHostKeyChecking=no -i "$PEM_FILE" ubuntu@$PUBLIC_IP <<EOF
  sudo mv /home/ubuntu/shutdown.sh /var/lib/cloud/scripts/per-instance/
  sudo chmod +x /var/lib/cloud/scripts/per-instance/shutdown.sh

  # 🔷 Add cronjob for app logs
  (crontab -l 2>/dev/null; echo "*/5 * * * * aws s3 cp /home/ubuntu/techeazy-devops/app.log s3://$S3_BUCKET/app-logs/app-\$(date +\\%Y-\\%m-\\%d_\\%H:\\%M:\\%S).log") | crontab -
EOF

echo "⏳ Waiting for app to start..."
sleep 30

STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$PUBLIC_IP:$APP_PORT)
if [[ "$STATUS_CODE" == "200" ]]; then
  echo "✅ App is reachable at: http://$PUBLIC_IP:$APP_PORT"
else
  echo "❌ App not reachable, status code: $STATUS_CODE"
fi

echo "⏱️ Instance will stop in $SHUTDOWN_TIMER seconds..."
sleep "$SHUTDOWN_TIMER"
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"

aws s3 cp "$LOG_FILE" s3://$S3_BUCKET/deployment-logs/"$LOG_FILE"
