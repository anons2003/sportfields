variable "name_prefix" { type = string }
variable "frontend_domain" { type = string }
variable "force_destroy_buckets" { type = bool }
variable "backup_noncurrent_version_expiration_days" { type = number }
variable "private_app_subnet_ids" { type = list(string) }
variable "efs_security_group_id" { type = string }
variable "backup_tag_key" { type = string }
variable "backup_tag_value" { type = string }
