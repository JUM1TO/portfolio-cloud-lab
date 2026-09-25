variable "aws_region" {
  description = "AWS region used for the portfolio lab."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Dedicated CIDR for the Terraform-managed portfolio environment."
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet."
  type        = string
  default     = "10.30.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type. t4g.micro uses ARM64."
  type        = string
  default     = "t4g.micro"
}

variable "github_repo_url" {
  description = "Public GitHub repository cloned by the EC2 bootstrap."
  type        = string
  default     = "https://github.com/JUM1TO/portfolio-cloud-lab.git"
}

variable "github_oidc_sub" {
  description = "Exact immutable GitHub OIDC subject allowed to assume the deploy role."
  type        = string
  default     = "repo:JUM1TO@318816686/portfolio-cloud-lab@1345504123:ref:refs/heads/main"
}
