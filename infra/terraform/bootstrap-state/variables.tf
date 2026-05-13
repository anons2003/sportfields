variable "project_name" {
  type    = string
  default = "sportfields"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  type    = string
  default = "sportfields-dev-terraform-state-529715002875"
}

variable "lock_table_name" {
  type    = string
  default = "sportfields-dev-terraform-locks"
}
