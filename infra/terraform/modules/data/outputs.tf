output "rds_endpoint" { value = aws_db_instance.this.address }
output "rds_port" { value = aws_db_instance.this.port }
output "redis_primary_endpoint" { value = aws_elasticache_replication_group.this.primary_endpoint_address }
output "redis_reader_endpoint" { value = aws_elasticache_replication_group.this.reader_endpoint_address }
