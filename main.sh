#!/bin/bash

echo "🚀 Script started"

STAGE=$1
if [ -z "$STAGE" ]; then
  echo "❌ Please provide stage name like: Dev or Prod"
  exit 1
fi

CONFIG_FILE="config/${STAGE,,}_config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"

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

echo "🚀 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --region "$REGION" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${STAGE}-Server}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "🆔 Instance ID: $INSTANCE_ID"

echo "⏳ Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "🌐 Fetching public IP..."
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "🌍 Public IP: $PUBLIC_IP"

echo "📦 Installing Java and deploying app..."
ssh -o StrictHostKeyChecking=no -i "$PEM_FILE" ubuntu@$PUBLIC_IP <<EOF
  sudo apt update -y
  sudo apt install -y wget apt-transport-https gnupg curl

  # Install Java 21 from Adoptium
  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /usr/share/keyrings/adoptium-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/adoptium-archive-keyring.gpg] https://packages.adoptium.net/artifactory/deb jammy main" | sudo tee /etc/apt/sources.list.d/adoptium.list
  sudo apt update
  sudo apt install -y temurin-21-jdk

  echo "export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64" >> ~/.bashrc
  echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.bashrc
  source ~/.bashrc

  git clone "$GIT_REPO"
  cd techeazy-devops
  chmod +x mvnw

  ./mvnw clean package -DskipTests

  JAR_FILE=\$(find target -type f -name "*.jar" | head -n 1)
  if [[ -f "\$JAR_FILE" ]]; then
    echo "🚀 Running \$JAR_FILE"
# Run the JAR with sudo (required for port 80)
sudo nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar > app.log 2>&1 &
  else
    echo "❌ Build failed or JAR not found"
    exit 1
  fi
EOF

echo "📥 Copying shutdown script to EC2..."
scp -o StrictHostKeyChecking=no -i "$PEM_FILE" scripts/shutdown.sh ubuntu@$PUBLIC_IP:/home/ubuntu/

echo "⚙️ Setting shutdown script..."
ssh -o StrictHostKeyChecking=no -i "$PEM_FILE" ubuntu@$PUBLIC_IP <<EOF
  sudo mv /home/ubuntu/shutdown.sh /var/lib/cloud/scripts/per-instance/
  sudo chmod +x /var/lib/cloud/scripts/per-instance/shutdown.sh
EOF


echo "⏳ Waiting for app to start..."
sleep 30

STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$PUBLIC_IP:$APP_PORT)
if [[ "$STATUS_CODE" == "200" ]]; then
  echo "✅ App is reachable at: http://$PUBLIC_IP:$APP_PORT"
else
  echo "❌ App not reachable, status code: $STATUS_CODE"
fi

echo "📄 Creating shutdown script to upload logs to S3..."
ssh -i "$PEM_FILE" ubuntu@$PUBLIC_IP <<EOF
  cat <<'SCRIPT' > /home/ubuntu/upload_logs.sh
#!/bin/bash
TIMESTAMP=\$(date +"%Y-%m-%d_%H-%M-%S")
aws s3 cp /home/ubuntu/techeazy-devops/app.log s3://$S3_BUCKET_NAME/\$TIMESTAMP-app.log
SCRIPT

  chmod +x /home/ubuntu/upload_logs.sh

  echo "🔧 Registering shutdown hook..."
  echo "@reboot root chmod +x /home/ubuntu/upload_logs.sh" | sudo tee -a /etc/crontab > /dev/null
  echo "@reboot root bash /home/ubuntu/upload_logs.sh" | sudo tee -a /etc/crontab > /dev/null
  echo "0 0 * * * root bash /home/ubuntu/upload_logs.sh" | sudo tee -a /etc/crontab > /dev/null

  # Register shutdown hook using systemd
  sudo bash -c 'cat <<SERVICE > /etc/systemd/system/upload-logs.service
[Unit]
Description=Upload logs to S3 before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/home/ubuntu/upload_logs.sh
RemainAfterExit=true

[Install]
WantedBy=halt.target reboot.target shutdown.target
SERVICE'

  sudo systemctl daemon-reexec
  sudo systemctl enable upload-logs.service
EOF



echo "⏱️ Instance will stop in $SHUTDOWN_TIMER seconds..."
sleep "$SHUTDOWN_TIMER"
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
