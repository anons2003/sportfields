terraform {
  backend "s3" {
    bucket         = "sportfields-dev-terraform-state-529715002875"
    key            = "sportfields/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "sportfields-dev-terraform-locks"
    encrypt        = true
  }
}
