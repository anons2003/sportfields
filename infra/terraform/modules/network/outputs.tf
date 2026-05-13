output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for subnet in values(aws_subnet.public) : subnet.id]
}

output "private_app_subnet_ids" {
  value = [for subnet in values(aws_subnet.private_app) : subnet.id]
}

output "private_data_subnet_ids" {
  value = [for subnet in values(aws_subnet.private_data) : subnet.id]
}

output "vpc_flow_log_group_name" {
  value = aws_cloudwatch_log_group.vpc_flow_logs.name
}
