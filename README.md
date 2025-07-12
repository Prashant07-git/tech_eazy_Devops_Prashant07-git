🚀 EC2 App Deployment & Log Upload Automation
This project automates:
✅ EC2 deployment of a Spring Boot app
✅ Uploading application & system logs to S3
✅ Automatic periodic log upload using a cron job

📋 Requirements
AWS Account Setup
IAM user with programmatic access (access keys configured on your machine).

IAM user must have at least these permissions:

ec2:*

iam:CreateRole, iam:PassRole, iam:CreateInstanceProfile

s3:*

cloudwatch:Get*, cloudwatch:Put* (optional, if you extend)

AWS CLI configured locally:

bash
Copy
Edit
aws configure
Local Tools
✅ Install:

Terraform (>= 1.5.0)

AWS CLI

OpenSSH (to SSH into EC2)

Maven (optional for local builds)

🗂️ Project Structure
perl
Copy
Edit
.
├── Config/
│   ├── dev_config.sh
│   └── prod_config.sh
├── keys/
│   └── TechEasy3.pem         # Your EC2 keypair file
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── versions.tf
│   └── dev.tfvars
├── deploy.sh                 # Main deployment & SSH script
└── README.md
🔷 AWS Resources Created
S3 bucket: for storing logs

Bucket name: techeazy-app-logs-dev

Lifecycle rule: deletes logs after 7 days

Server-side encryption: AES256

EC2 instance (app server):

Ubuntu 22.04

Runs Spring Boot app

IAM Role attached with AmazonS3FullAccess

Security group allowing: SSH (22), HTTP (80)

Cron job:

Uploads logs every minute to S3

Logs stored:

/home/ubuntu/app.log

/var/log/syslog

🔷 IAM Role & Policy
Terraform automatically creates:
✅ IAM role for EC2 with trust policy:

json
Copy
Edit
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
✅ IAM policy attached: AmazonS3FullAccess

✅ Instance profile: attached to EC2

🚀 How to Deploy
1️⃣ Prepare variables
Edit dev.tfvars:

hcl
Copy
Edit
stage         = "dev"
region        = "ap-south-1"
key_name      = "TechEasy3"
bucket_name   = "techeazy-app-logs-dev"
Make sure Config/dev_config.sh contains:

bash
Copy
Edit
REGION="ap-south-1"
KEY_NAME="TechEasy3"
PEM_FILE="keys/TechEasy3.pem"
2️⃣ Provision Infrastructure
bash
Copy
Edit
cd terraform
terraform init
terraform apply -var-file="dev.tfvars"
After apply, note the output:

instance_public_ip

log_server_public_ip

s3_bucket_name

3️⃣ Deploy App & Setup Logs
Run the deployment script:

bash
Copy
Edit
bash deploy.sh Dev
✅ This script:

SSH into EC2

Installs Java, Maven, AWS CLI

Clones & builds the Spring Boot app

Runs it on port 80

Creates /home/ubuntu/upload-logs.sh

Schedules cron job (crontab -l to verify)

🔷 Verify Logs
✅ Application is accessible at:

cpp
Copy
Edit
http://<instance_public_ip>:80
✅ Logs on S3:

arduino
Copy
Edit
s3://techeazy-app-logs-dev/app_logs/
s3://techeazy-app-logs-dev/ec2_logs/
Or list with CLI:

bash
Copy
Edit
aws s3 ls s3://techeazy-app-logs-dev/app_logs/ --region ap-south-1
aws s3 ls s3://techeazy-app-logs-dev/ec2_logs/ --region ap-south-1
🛠️ Notes & Tips
✅ If logs don’t appear automatically:

SSH into instance

Run crontab -l — ensure cron job is present

Check if cron is active:

bash
Copy
Edit
sudo systemctl status cron
Start if needed:

bash
Copy
Edit
sudo systemctl start cron
Run log upload manually:

bash
Copy
Edit
bash /home/ubuntu/upload-logs.sh
✅ To view cron output:

bash
Copy
Edit
cat /home/ubuntu/log-upload-cron.log
✅ To destroy infrastructure:

bash
Copy
Edit
terraform destroy -var-file="dev.tfvars"
