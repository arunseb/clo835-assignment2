output "ec2_instance_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.app_instance.public_ip
}

output "ecr_webapp_repository_url" {
  description = "ECR URL for webapp"
  value       = aws_ecr_repository.webapp.repository_url
}

output "ecr_mysql_repository_url" {
  description = "ECR URL for MySQL"
  value       = aws_ecr_repository.mysql.repository_url
}
