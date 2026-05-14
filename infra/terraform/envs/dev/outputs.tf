output "frontend_url" {
  value = "https://${var.frontend_subdomain}.${var.domain_name}"
}

output "api_url" {
  value = "https://${var.api_subdomain}.${var.domain_name}"
}

output "asset_url" {
  value = "https://${var.asset_subdomain}.${var.domain_name}"
}

output "user_asset_bucket" {
  value = module.storage.user_asset_bucket_id
}

output "backup_bucket" {
  value = module.storage.backup_bucket_id
}

output "frontend_bucket" {
  value = module.storage.frontend_bucket_id
}

output "rds_endpoint" {
  value = module.data.rds_endpoint
}

output "redis_primary_endpoint" {
  value = module.data.redis_primary_endpoint
}

output "assets_cloudfront_domain_name" {
  value = module.edge.assets_cloudfront_domain_name
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "vpc_flow_log_group_name" {
  value = module.network.vpc_flow_log_group_name
}

output "efs_file_system_id" {
  value = module.storage.efs_file_system_id
}

output "w5_backup_vault_name" {
  value = module.observability.backup_vault_name
}

output "w5_backup_plan_id" {
  value = module.observability.backup_plan_id
}
