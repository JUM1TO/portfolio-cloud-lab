output "vpc_id" {
  description = "Terraform-managed portfolio VPC ID."
  value       = aws_vpc.portfolio.id
}

output "instance_id" {
  description = "Terraform-managed portfolio EC2 instance ID."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Current public IPv4 address of the portfolio EC2 instance."
  value       = aws_instance.web.public_ip
}

output "site_url" {
  description = "HTTP URL for the portfolio before domain/TLS is configured."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "github_deploy_role_arn" {
  description = "IAM role ARN GitHub Actions should assume through OIDC."
  value       = aws_iam_role.github_deploy.arn
}
