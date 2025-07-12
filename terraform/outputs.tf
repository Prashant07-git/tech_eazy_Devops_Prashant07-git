output "instance_id" {
  value = aws_instance.app_server.id
}

output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app_logs.id
}
