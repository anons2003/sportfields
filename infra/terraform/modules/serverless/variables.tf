variable "name_prefix" { type = string }
variable "user_asset_bucket_id" { type = string }
variable "user_asset_bucket_arn" { type = string }
variable "kms_key_arn" { type = string }

variable "resize_image_rate_limit" {
  type    = number
  default = 10
}

variable "resize_image_burst_limit" {
  type    = number
  default = 20
}

variable "resize_image_reserved_concurrency" {
  type    = number
  default = 10
}
