# Portfolio Terraform v1

This folder creates a **parallel Terraform-managed portfolio environment**.

It intentionally does **not** import, reference, modify, or destroy the existing FILPRO VPC or the manually-created portfolio VPC.

## What it creates

- Dedicated VPC: `10.30.0.0/16`
- Public subnet: `10.30.1.0/24`
- Internet Gateway
- Public route table
- Security Group with HTTP/80 only (no SSH)
- IAM role + instance profile for AWS Systems Manager
- Amazon Linux 2023 ARM64 EC2 (`t4g.micro`)
- NGINX + Git + rsync bootstrap
- GitHub Actions OIDC deployment IAM role and least-privilege SSM policy

## Before apply

Confirm the active AWS identity:

```powershell
aws sts get-caller-identity
```

Then:

```powershell
terraform fmt
terraform validate
terraform plan -out=tfplan
```

Review the plan carefully. Expected changes should only contain resources whose names end in `-tf` or belong to the `10.30.0.0/16` portfolio Terraform environment.

Apply the reviewed plan:

```powershell
terraform apply tfplan
```

## After apply

```powershell
terraform output
```

You will need these outputs:

- `instance_id`
- `site_url`
- `github_deploy_role_arn`

Update `.github/workflows/deploy.yml` so GitHub Actions assumes the new Terraform-managed role and sends the SSM command to the new instance ID.

Do **not** destroy the manually-created portfolio environment until the new URL works and GitHub Actions has successfully deployed to it.

## Safety boundary

FILPRO is out of scope. Nothing in this Terraform configuration should reference FILPRO resources.

## Cleanup

Only after you have intentionally migrated away from this Terraform environment:

```powershell
terraform plan -destroy
terraform destroy
```

`terraform destroy` only targets resources tracked by this Terraform state, but always review the destroy plan first.
