module "network" {
  source = "../../modules/network"

  name_prefix               = local.name_prefix
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  single_nat_gateway        = var.single_nat_gateway
}

module "security" {
  source = "../../modules/security"

  name_prefix  = local.name_prefix
  vpc_id       = module.network.vpc_id
  backend_port = var.backend_port
}

module "storage" {
  source = "../../modules/storage"

  name_prefix                               = local.name_prefix
  frontend_domain                           = "${var.frontend_subdomain}.${var.domain_name}"
  force_destroy_buckets                     = var.force_destroy_buckets
  backup_noncurrent_version_expiration_days = var.backup_noncurrent_version_expiration_days
}

module "data" {
  source = "../../modules/data"

  name_prefix              = local.name_prefix
  private_data_subnet_ids  = module.network.private_data_subnet_ids
  rds_security_group_id    = module.security.rds_security_group_id
  redis_security_group_id  = module.security.redis_security_group_id
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = var.db_password
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_multi_az              = var.db_multi_az
  db_deletion_protection   = var.db_deletion_protection
  db_skip_final_snapshot   = var.db_skip_final_snapshot
  redis_node_type          = var.redis_node_type
  redis_engine_version     = var.redis_engine_version
  redis_num_cache_clusters = var.redis_num_cache_clusters
  kms_key_arn              = module.storage.kms_key_arn
}

module "compute" {
  source = "../../modules/compute"

  name_prefix                       = local.name_prefix
  vpc_id                            = module.network.vpc_id
  public_subnet_ids                 = module.network.public_subnet_ids
  private_app_subnet_ids            = module.network.private_app_subnet_ids
  alb_security_group_id             = module.security.alb_security_group_id
  ec2_security_group_id             = module.security.ec2_security_group_id
  backend_port                      = var.backend_port
  backend_instance_type             = var.backend_instance_type
  root_volume_size                  = var.root_volume_size
  enable_detailed_monitoring        = var.enable_detailed_monitoring
  asg_min_size                      = var.asg_min_size
  asg_desired_capacity              = var.asg_desired_capacity
  asg_max_size                      = var.asg_max_size
  alb_deletion_protection           = var.alb_deletion_protection
  artifact_bucket                   = var.backend_artifact_bucket
  artifact_key                      = var.backend_artifact_key
  backend_env_ssm_parameter_name    = var.backend_env_ssm_parameter_name
  ec2_key_pair_name                 = var.ec2_key_pair_name
  api_domain_name                   = "${var.api_subdomain}.${var.domain_name}"
  api_certificate_validation_method = var.api_certificate_validation_method
  route53_zone_id                   = var.route53_zone_id
  s3_user_asset_bucket_arn          = module.storage.user_asset_bucket_arn
  s3_backup_bucket_arn              = module.storage.backup_bucket_arn
  cloudwatch_log_group_name         = module.observability.backend_log_group_name
  kms_key_arn                       = module.storage.kms_key_arn
}

module "edge" {
  source = "../../modules/edge"

  name_prefix                            = local.name_prefix
  route53_zone_id                        = var.route53_zone_id
  frontend_domain_name                   = "${var.frontend_subdomain}.${var.domain_name}"
  api_domain_name                        = "${var.api_subdomain}.${var.domain_name}"
  frontend_bucket_id                     = module.storage.frontend_bucket_id
  frontend_bucket_arn                    = module.storage.frontend_bucket_arn
  frontend_bucket_regional_domain_name   = module.storage.frontend_bucket_regional_domain_name
  user_asset_bucket_id                   = module.storage.user_asset_bucket_id
  user_asset_bucket_arn                  = module.storage.user_asset_bucket_arn
  user_asset_bucket_regional_domain_name = module.storage.user_asset_bucket_regional_domain_name
  frontend_certificate_arn               = var.frontend_acm_certificate_arn
  asset_domain_name                      = "${var.asset_subdomain}.${var.domain_name}"
  alb_dns_name                           = module.compute.alb_dns_name
  alb_zone_id                            = module.compute.alb_zone_id
  alb_arn                                = module.compute.alb_arn
  waf_enable_rate_limit                  = var.waf_enable_rate_limit
  waf_rate_limit                         = var.waf_rate_limit
}

module "observability" {
  source = "../../modules/observability"

  name_prefix                = local.name_prefix
  enable_security_hub        = var.enable_security_hub
  enable_cloudtrail          = var.enable_cloudtrail
  enable_aws_config          = var.enable_aws_config
  kms_key_arn                = module.storage.kms_key_arn
  force_destroy_audit_bucket = var.force_destroy_audit_bucket
}
