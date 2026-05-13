variable "project_name" {
  type        = string
  description = "Project slug used for naming."
  default     = "sportfields"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS region for regional resources."
  default     = "ap-southeast-1"
}

variable "availability_zones" {
  type        = list(string)
  description = "Two AZs for the VPC layout."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for ALB and NAT public subnets."
}

variable "private_app_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for backend EC2 subnets."
}

variable "private_data_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for RDS and Redis subnets."
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use one NAT gateway for cost savings in dev."
  default     = true
}

variable "domain_name" {
  type        = string
  description = "Root domain managed in Route53."
}

variable "route53_zone_id" {
  type        = string
  description = "Hosted zone ID for the domain."
}

variable "frontend_subdomain" {
  type        = string
  description = "Subdomain for the frontend."
  default     = "app"
}

variable "api_subdomain" {
  type        = string
  description = "Subdomain for the backend API."
  default     = "api"
}

variable "asset_subdomain" {
  type        = string
  description = "Subdomain for public uploaded assets served through CloudFront."
  default     = "assets"
}

variable "frontend_acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN in us-east-1 for CloudFront. Must cover frontend and asset hostnames, or be a wildcard certificate."
}

variable "api_certificate_validation_method" {
  type        = string
  description = "Validation method for API ACM certificate."
  default     = "DNS"
}

variable "backend_instance_type" {
  type        = string
  description = "EC2 instance type for backend."
  default     = "t3.small"
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB for backend instances."
  default     = 20
}

variable "enable_detailed_monitoring" {
  type        = bool
  description = "Enable EC2 detailed monitoring for backend instances."
  default     = false
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 2
}

variable "alb_deletion_protection" {
  type        = bool
  description = "Enable ALB deletion protection. Keep false in dev unless the stack is shared."
  default     = false
}

variable "backend_artifact_bucket" {
  type        = string
  description = "S3 bucket containing backend deploy bundle tarball."
}

variable "backend_artifact_key" {
  type        = string
  description = "S3 object key for backend deploy bundle tarball."
}

variable "backend_env_ssm_parameter_name" {
  type        = string
  description = "SSM parameter containing backend env file contents."
}

variable "ec2_key_pair_name" {
  type        = string
  description = "Optional EC2 key pair name for SSH access."
  default     = null
}

variable "backend_port" {
  type    = number
  default = 5001
}

variable "db_name" {
  type    = string
  default = "sportfields"
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type        = bool
  description = "Enable Multi-AZ RDS. Keep false for dev cost control; set true for production."
  default     = false
}

variable "db_deletion_protection" {
  type        = bool
  description = "Protect RDS from accidental deletion."
  default     = false
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot on DB destroy. Use false for production."
  default     = true
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "redis_engine_version" {
  type    = string
  default = "7.1"
}

variable "redis_num_cache_clusters" {
  type        = number
  description = "Number of Redis cache nodes. Use 1 for dev, 2+ for automatic failover."
  default     = 1

  validation {
    condition     = var.redis_num_cache_clusters >= 1
    error_message = "redis_num_cache_clusters must be at least 1."
  }
}

variable "enable_security_hub" {
  type    = bool
  default = true
}

variable "enable_cloudtrail" {
  type    = bool
  default = true
}

variable "enable_aws_config" {
  type    = bool
  default = true
}

variable "force_destroy_buckets" {
  type        = bool
  description = "Allow Terraform destroy to delete non-empty app buckets. Keep false outside disposable dev stacks."
  default     = false
}

variable "force_destroy_audit_bucket" {
  type        = bool
  description = "Allow Terraform destroy to delete the audit bucket. Keep false outside disposable dev stacks."
  default     = false
}

variable "backup_noncurrent_version_expiration_days" {
  type        = number
  description = "Days to retain noncurrent backup object versions."
  default     = 30
}

variable "waf_enable_rate_limit" {
  type    = bool
  default = true
}

variable "waf_rate_limit" {
  type    = number
  default = 2000
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
