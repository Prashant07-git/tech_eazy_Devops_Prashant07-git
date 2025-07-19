#!/bin/bash

echo "[INFO] Checking and importing existing AWS resources…"

region="ap-south-1"
sgName="dev-ec2-sg"
roleName="dev-ec2-s3-role"
profileName="dev-s3-upload-profile"
bucketName="techeazy-app-logs-dev"

cd ec2-automation/terraform

terraform init -input=false

# Security Group
sgId=$(aws ec2 describe-security-groups --region "$region" --filters Name=group-name,Values="$sgName" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [[ "$sgId" != "None" && -n "$sgId" ]]; then
    echo "[OK] Security Group '$sgName' exists with ID: $sgId"
    echo "[INFO] Importing Security Group into Terraform state…"
    terraform import -var-file="dev.tfvars" aws_security_group.ec2_sg "$sgId"
else
    echo "[INFO] Security Group '$sgName' does not exist. Terraform will create it."
fi

# IAM Role
if aws iam get-role --role-name "$roleName" >/dev/null 2>&1; then
    echo "[OK] IAM Role '$roleName' exists"
    echo "[INFO] Importing IAM Role into Terraform state…"
    terraform import -var-file="dev.tfvars" aws_iam_role.ec2_s3_role "$roleName"
else
    echo "[INFO] IAM Role '$roleName' does not exist. Terraform will create it."
fi

# IAM Instance Profile
if aws iam get-instance-profile --instance-profile-name "$profileName" >/dev/null 2>&1; then
    echo "[OK] IAM Instance Profile '$profileName' exists"
    echo "[INFO] Importing IAM Instance Profile into Terraform state…"
    terraform import -var-file="dev.tfvars" aws_iam_instance_profile.s3_upload_profile "$profileName"
else
    echo "[INFO] IAM Instance Profile '$profileName' does not exist. Terraform will create it."
fi

# S3 Bucket
if aws s3api head-bucket --bucket "$bucketName" >/dev/null 2>&1; then
    echo "[OK] S3 Bucket '$bucketName' exists"
    echo "[INFO] Importing S3 Bucket into Terraform state…"
    terraform import -var-file="dev.tfvars" aws_s3_bucket.app_logs "$bucketName"
else
    echo "[INFO] S3 Bucket '$bucketName' does not exist. Terraform will create it."
fi

echo "[OK] Pre-import complete. You can now run 'terraform plan -var-file=dev.tfvars' and 'terraform apply -var-file=dev.tfvars'."
