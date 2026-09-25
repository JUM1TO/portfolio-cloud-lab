output "vpc_id" {
  description = "Terraform-managed portfolio VPC ID."
  value       = aws_vpc.portfolio.id
}

output "instance_id" {
  description = "Terraform-managed portfolio EC2 instance ID."
  value       = aws_instance.web.id
}

output "github_deploy_role_arn" {
  description = "IAM role ARN GitHub Actions should assume through OIDC."
  value       = aws_iam_role.github_deploy.arn
}

output "elastic_ip" {
  description = "Elastic IPv4 address assigned to the portfolio EC2 instance."
  value       = aws_eip.web.public_ip
}

output "site_url" {
  description = "Public portfolio URL."
  value       = "https://jumito.dev"
}