output "alb_dns_name" { value = aws_lb.this.dns_name }
output "alb_zone_id" { value = aws_lb.this.zone_id }
output "alb_arn" { value = aws_lb.this.arn }
output "target_group_arn" { value = aws_lb_target_group.backend.arn }
output "api_certificate_arn" { value = aws_acm_certificate_validation.api.certificate_arn }
