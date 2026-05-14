output "backend_log_group_name" { value = aws_cloudwatch_log_group.backend.name }
output "audit_bucket_id" { value = aws_s3_bucket.audit.id }
output "backup_vault_name" { value = aws_backup_vault.w5.name }
output "backup_plan_id" { value = aws_backup_plan.w5.id }
