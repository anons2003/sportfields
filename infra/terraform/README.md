# SportFields Terraform

This folder provisions the agreed AWS shape for SportFields:

- Frontend: `Route53 -> CloudFront -> S3`
- Backend: `Route53 -> ALB -> EC2 Auto Scaling Group`
- Data: `RDS PostgreSQL`, `ElastiCache Redis` (`dev` defaults to non-HA sizing; production can enable Multi-AZ/failover)
- Assets: `CloudFront -> private S3 user asset bucket`, `S3 backup bucket`
- Security/ops: `KMS`, `CloudTrail`, `AWS Config`, `Security Hub`, `CloudWatch`

## Layout

- `bootstrap-state`: one-time stack that creates the S3 state bucket and DynamoDB lock table
- `envs/dev`: root stack for the `dev` environment
- `modules/*`: reusable Terraform modules
- `templates/user-data.sh.tftpl`: EC2 bootstrap script for backend instances
- `TERRAFORM_COMMON.md`: Vietnamese common-stack guide, runbook, and production checklist

## Assumptions

- AWS CLI is configured with a profile that can create resources in `us-east-1`
- The current lab account denies VPC creation in `ap-southeast-1`, so dev uses `us-east-1`
- Frontend ACM certificate already exists in `us-east-1`
- Hosted zone already exists in Route53
- Backend deploy artifact is published as a tarball in S3
- Backend env file is stored in SSM Parameter Store as a single secure string

## State bootstrap

Create the remote state bucket and lock table once before using `envs/dev`:

```bash
cd infra/terraform/bootstrap-state
terraform init
terraform apply
```

The dev stack uses:

- S3 bucket: `sportfields-dev-terraform-state-529715002875`
- State key: `sportfields/dev/terraform.tfstate`
- DynamoDB lock table: `sportfields-dev-terraform-locks`
- Region: `us-east-1`

If local state already exists, migrate it after the bootstrap stack is applied:

```bash
cd infra/terraform/envs/dev
terraform init -migrate-state
```

## Dev setup

```bash
cd infra/terraform/envs/dev
cp dev.tfvars.example dev.tfvars
```

Edit `dev.tfvars` with real values:

- `domain_name`: `topjob.id.vn`
- `route53_zone_id`: Route53 hosted zone ID for `topjob.id.vn`
- `frontend_acm_certificate_arn`: ACM ARN in `us-east-1` covering `app.topjob.id.vn` and `assets.topjob.id.vn`, or a wildcard
- `backend_artifact_bucket`: S3 bucket containing the backend release tarball
- `backend_artifact_key`: object key for the backend release tarball
- `backend_env_ssm_parameter_name`: SSM SecureString containing the backend env file
- `db_password`: local-only database password; never commit `dev.tfvars`

Then deploy:

```bash
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

Destroy dev resources when they are no longer needed, especially because NAT Gateway has an hourly cost:

```bash
terraform destroy -var-file=dev.tfvars
```

For the common-stack explanation and production hardening checklist, read `TERRAFORM_COMMON.md`.

## What this stack configures

- VPC with:
  - 2 public subnets
  - 2 private app subnets
  - 2 private data subnets
- NAT gateway strategy controlled by `single_nat_gateway`
- VPC Flow Logs to CloudWatch Logs
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
- Rotate any AWS access key that was shared in chat, terminal history, screenshots, or committed files.
