resource "aws_instance" "log_server" {
  ami                         = "ami-03f4878755434977f" # Ubuntu 22.04 in ap-south-1
  instance_type               = "t2.micro"
  key_name                    = "TechEasy3"
  subnet_id                   = data.aws_subnet.default.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.s3_upload_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "${var.stage}-log-server"
  }

  provisioner "remote-exec" {
  inline = [
    "sudo apt update -y",
    "sudo mkdir -p /home/ubuntu/logs/app_logs /home/ubuntu/logs/ec2_logs",
    "sudo chown -R ubuntu:ubuntu /home/ubuntu/logs",
    "sudo chmod -R 755 /home/ubuntu/logs"
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${var.key_name}.pem")
    host        = self.public_ip
  }
}


 user_data = <<-EOF
              #!/bin/bash
              set -e
              export AWS_REGION="ap-south-1"
              S3_BUCKET="techeazy-app-logs-dev"
              LOG_DIR="/home/ubuntu/logs"

              mkdir -p $LOG_DIR/app_logs
              mkdir -p $LOG_DIR/ec2_logs

              # Install AWS CLI if needed
              apt-get update -y
              apt-get install -y awscli

              # Create log fetcher script
              cat > /home/ubuntu/fetch-logs.sh <<EOL
              #!/bin/bash
              export AWS_REGION="ap-south-1"
              S3_BUCKET="techeazy-app-logs-dev"
              LOG_DIR="/home/ubuntu/logs"
              TIMESTAMP=\$(date +"%Y-%m-%d_%H-%M-%S")

              mkdir -p \$LOG_DIR/app_logs
              mkdir -p \$LOG_DIR/ec2_logs

              aws s3 sync s3://\$S3_BUCKET/app_logs/ \$LOG_DIR/app_logs/ --region \$AWS_REGION
              aws s3 sync s3://\$S3_BUCKET/ec2_logs/ \$LOG_DIR/ec2_logs/ --region \$AWS_REGION
              EOL

              chmod +x /home/ubuntu/fetch-logs.sh

              # Schedule cron job every 5 min
              (crontab -l 2>/dev/null; echo "*/5 * * * * /home/ubuntu/fetch-logs.sh >> /home/ubuntu/logs/fetch-cron.log 2>&1") | crontab -
              EOF
}



output "log_server_public_ip" {
  value = aws_instance.log_server.public_ip
}