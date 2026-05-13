# SportFields Terraform

This folder provisions the agreed AWS shape for SportFields:

- Frontend: `Route53 -> CloudFront -> S3`
- Backend: `Route53 -> ALB -> EC2 Auto Scaling Group`
- Data: `RDS PostgreSQL`, `ElastiCache Redis` (`dev` defaults to non-HA sizing; production can enable Multi-AZ/failover)
- Assets: `CloudFront -> private S3 user asset bucket`, `S3 backup bucket`
- Security/ops: `KMS`, `CloudTrail`, `AWS Config`, `Security Hub`, `CloudWatch`

## Layout

- `envs/dev`: root stack for the `dev` environment
- `modules/*`: reusable Terraform modules
- `templates/user-data.sh.tftpl`: EC2 bootstrap script for backend instances
- `TERRAFORM_COMMON.md`: Vietnamese common-stack guide, runbook, and production checklist

## Assumptions

- Frontend ACM certificate already exists in `us-east-1`
- Hosted zone already exists in Route53
- Backend deploy artifact is published as a tarball in S3
- Backend env file is stored in SSM Parameter Store as a single secure string

## Dev bootstrap

```bash
cd infra/terraform/envs/dev
cp dev.tfvars.example dev.tfvars
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

For the common-stack explanation and production hardening checklist, read `TERRAFORM_COMMON.md`.

## What this stack configures

- VPC with:
  - 2 public subnets
  - 2 private app subnets
  - 2 private data subnets
- NAT gateway strategy controlled by `single_nat_gateway`
- ALB, target group, HTTPS listener, and ASG-backed EC2 instances
- RDS and Redis in private data subnets
- 3 S3 buckets:
  - frontend static assets
  - user assets
  - backup/audit artifacts
- CloudFront + Route53 aliases for `app` and `api`
- Optional regional WAF on ALB
- CloudTrail, AWS Config, Security Hub, CloudWatch log group

## Notable production notes

- CloudFront certificate must stay in `us-east-1` and cover `app.<domain>` plus `assets.<domain>`, or be a wildcard certificate
- The `dev` stack defaults to one NAT gateway, one backend instance, single-AZ RDS, and one Redis node to reduce cost
- For production, prefer one NAT gateway per AZ, at least two backend instances, Multi-AZ RDS, Redis failover, and stronger autoscaling policies
- Stripe webhook should point to `https://api.<domain>/api/payments/webhook`
