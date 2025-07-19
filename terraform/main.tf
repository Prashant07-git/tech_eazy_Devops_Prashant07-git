



data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  default_for_az    = true
  availability_zone = data.aws_availability_zones.available.names[0]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.stage}-ec2-sg"
  description = "Security group for ${var.stage} EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "${var.stage}-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "s3_upload_profile" {
  name = "${var.stage}-s3-upload-profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_s3_bucket" "app_logs" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "log_expiry" {
  bucket = aws_s3_bucket.app_logs.id

  rule {
    id     = "DeleteOldLogs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7
    }
  }
}

resource "aws_instance" "app_server" {
  ami                    = "ami-03f4878755434977f"
  instance_type          = "t2.micro"
  key_name               = "TechEasy3"
  subnet_id              = data.aws_subnet.default.id
  iam_instance_profile   = aws_iam_instance_profile.s3_upload_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "${var.stage}-Server"
  }
}

