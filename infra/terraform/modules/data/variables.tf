variable "name_prefix" { type = string }
variable "private_data_subnet_ids" { type = list(string) }
variable "rds_security_group_id" { type = string }
variable "redis_security_group_id" { type = string }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_instance_class" { type = string }
variable "db_allocated_storage" { type = number }
variable "db_multi_az" { type = bool }
variable "db_deletion_protection" { type = bool }
variable "db_skip_final_snapshot" { type = bool }
variable "redis_node_type" { type = string }
variable "redis_engine_version" { type = string }
variable "redis_num_cache_clusters" { type = number }
variable "kms_key_arn" { type = string }
