# SportFields Terraform Common

Tai lieu nay mo ta bo Terraform common cho SportFields trong thu muc `infra/terraform`.
Stack nay duoc rebuild dua tren project goc o `/Users/anons/Documents/SportFields/sportfields`,
nhung da loai bo cache sinh ra boi Terraform va chuan hoa lai cac module dung chung.

## Muc tieu

- Tao nen tang AWS dung chung cho moi truong `dev`.
- Tach ha tang theo module de co the tai su dung cho `staging` hoac `production`.
- Giu cac thanh phan public toi thieu: CloudFront, ALB, Route53.
- Dat backend, RDS va Redis trong private subnet.
- Ap dung mac dinh an toan cho S3, KMS, EC2, CloudTrail va security group.

## Cau truc

```text
infra/terraform
|-- bootstrap-state
|   |-- versions.tf
|   |-- providers.tf
|   |-- variables.tf
|   |-- main.tf
|   `-- outputs.tf
|-- envs
|   `-- dev
|       |-- backend.tf
|       |-- versions.tf
|       |-- providers.tf
|       |-- variables.tf
|       |-- locals.tf
|       |-- main.tf
|       |-- outputs.tf
|       `-- dev.tfvars.example
|-- modules
|   |-- network
|   |-- security
|   |-- storage
|   |-- data
|   |-- compute
|   |-- edge
|   `-- observability
|-- templates
|   `-- user-data.sh.tftpl
`-- TERRAFORM_COMMON.md
```

## Kien truc AWS

- `bootstrap-state`: S3 bucket cho Terraform state va DynamoDB table cho state lock.
- `network`: VPC, Internet Gateway, public subnets, private app subnets, private data subnets, NAT Gateway, VPC Flow Logs.
- `security`: security groups rieng cho ALB, EC2 backend, RDS PostgreSQL va Redis.
- `storage`: KMS key, S3 frontend bucket, user asset bucket, backup bucket.
- `data`: RDS PostgreSQL va ElastiCache Redis trong private data subnets.
- `compute`: ACM certificate cho API, ALB HTTPS, EC2 Launch Template, Auto Scaling Group.
- `edge`: CloudFront cho frontend va user assets, Route53 alias records, optional WAF cho ALB.
- `observability`: CloudWatch log group, audit bucket, CloudTrail, AWS Config, Security Hub.

## Cac diem da clean khi rebuild

- Khong copy `.terraform/` tu project goc.
- EC2 Launch Template bat IMDSv2 bat buoc.
- Root EBS volume duoc ma hoa bang KMS va dung `gp3`.
- IAM policy cua EC2 duoc scope theo S3 bucket, SSM parameter, KMS key va CloudWatch log group cu the.
- ALB bat `drop_invalid_header_fields`.
- S3 bucket bat public access block, versioning, SSE-KMS va bucket-owner-enforced ownership.
- Backup bucket co lifecycle xoa noncurrent versions sau so ngay cau hinh.
- CloudTrail bat log file validation va ghi vao audit bucket rieng.
- Terraform da duoc format va validate thanh cong trong `envs/dev`.

## Dieu kien truoc khi apply

- AWS CLI da dang nhap vao account dung va profile co quyen tao resource o `us-east-1`.
- Chay bootstrap remote state truoc khi team cung dung stack:
  `terraform -chdir=infra/terraform/bootstrap-state init && terraform -chdir=infra/terraform/bootstrap-state apply`.
- Hosted zone Route53 da ton tai va co `route53_zone_id`.
- ACM certificate cho CloudFront da ton tai tai `us-east-1`, cover `app.<domain>` va `assets.<domain>` hoac wildcard.
- Backend artifact da duoc upload len S3, vi du `s3://sportfields-deployments-dev/backend/releases/latest.tar.gz`.
- SSM Parameter Store da co secure string chua file env backend, vi du `/sportfields/dev/backend/env`.
- Gia tri `db_password` khong commit vao git. Dung local `dev.tfvars` hoac secret manager cua CI.

## Chay dev

```bash
cd infra/terraform/envs/dev
cp dev.tfvars.example dev.tfvars
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

Neu state da ton tai local tu lan deploy truoc, sau khi bootstrap S3/DynamoDB hay chay:

```bash
terraform -chdir=infra/terraform/envs/dev init -migrate-state
```

## Bien quan trong

- `domain_name`: root domain trong Route53.
- `route53_zone_id`: hosted zone ID cua domain.
- `frontend_acm_certificate_arn`: certificate ARN o `us-east-1` cho CloudFront.
- `backend_artifact_bucket`: bucket chua backend tarball.
- `backend_artifact_key`: object key cua backend tarball.
- `backend_env_ssm_parameter_name`: SSM parameter chua env file.
- `single_nat_gateway`: `true` de tiet kiem chi phi dev, `false` cho production resilience.
- `vpc_flow_log_retention_days`: so ngay giu VPC Flow Logs trong CloudWatch Logs.
- `db_multi_az`: `false` mac dinh cho dev, nen `true` cho production.
- `redis_num_cache_clusters`: `1` cho dev, `2+` de bat failover.
- `force_destroy_buckets`: chi nen `true` voi stack test co the xoa du lieu.
- `force_destroy_audit_bucket`: chi nen `true` voi stack test, khong nen dung cho audit that.

## Checklist production

- Dat `single_nat_gateway = false`.
- Dat `asg_min_size >= 2` va `asg_desired_capacity >= 2`.
- Bat `db_multi_az = true`.
- Dat `db_deletion_protection = true` va `db_skip_final_snapshot = false`.
- Dat `redis_num_cache_clusters >= 2`.
- Dat `alb_deletion_protection = true`.
- Giu `force_destroy_buckets = false` va `force_destroy_audit_bucket = false`.
- Xem lai WAF rate limit theo traffic thuc te.
- Dung remote backend cho Terraform state, vi du S3 + DynamoDB lock.
- Rotate/delete moi AWS access key tung bi share qua chat, screenshot, terminal history hoac file local.

## Validate da chay

```bash
terraform fmt -recursive infra/terraform
terraform -chdir=infra/terraform/envs/dev init -backend=false
terraform -chdir=infra/terraform/envs/dev validate
```

Ket qua validate: configuration hop le.
