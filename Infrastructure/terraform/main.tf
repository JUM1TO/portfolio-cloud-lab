data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_vpc" "portfolio" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "portfolio-vpc-tf"
  }
}

resource "aws_internet_gateway" "portfolio" {
  vpc_id = aws_vpc.portfolio.id

  tags = {
    Name = "portfolio-igw-tf"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.portfolio.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "portfolio-public-a-tf"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.portfolio.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.portfolio.id
  }

  tags = {
    Name = "portfolio-public-rt-tf"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "portfolio-web-sg-tf"
  description = "Public HTTP access for the portfolio; no SSH."
  vpc_id      = aws_vpc.portfolio.id

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "portfolio-web-sg-tf"
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name = "portfolio-ec2-ssm-role-tf"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "portfolio-ec2-ssm-role-tf"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "portfolio-ec2-profile-tf"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    github_repo_url = var.github_repo_url
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "portfolio-web-tf"
  }

  depends_on = [
    aws_internet_gateway.portfolio,
    aws_route_table_association.public_a,
    aws_iam_role_policy_attachment.ec2_ssm_core
  ]
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_oidc_sub]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "portfolio-github-deploy-role-tf"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = {
    Name = "portfolio-github-deploy-role-tf"
  }
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid     = "SendCommandToPortfolioInstance"
    effect  = "Allow"
    actions = ["ssm:SendCommand"]

    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
      aws_instance.web.arn
    ]
  }

  statement {
    sid       = "ReadCommandResult"
    effect    = "Allow"
    actions   = ["ssm:GetCommandInvocation"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_deploy" {
  name        = "portfolio-github-deploy-policy-tf"
  description = "Least-privilege SSM deployment policy for the Terraform-managed portfolio EC2 instance."
  policy      = data.aws_iam_policy_document.github_deploy.json
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = aws_iam_policy.github_deploy.arn
}

data "aws_route53_zone" "jumito" {
  name         = "jumito.dev."
  private_zone = false
}

resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name = "portfolio-web-eip-tf"
  }

  depends_on = [
    aws_internet_gateway.portfolio
  ]
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.jumito.zone_id
  name    = "jumito.dev"
  type    = "A"
  ttl     = 300

  records = [aws_eip.web.public_ip]
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.jumito.zone_id
  name    = "www.jumito.dev"
  type    = "A"
  ttl     = 300

  records = [aws_eip.web.public_ip]
}
