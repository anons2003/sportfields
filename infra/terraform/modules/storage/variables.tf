variable "name_prefix" { type = string }
variable "frontend_domain" { type = string }
variable "force_destroy_buckets" { type = bool }
variable "backup_noncurrent_version_expiration_days" { type = number }
