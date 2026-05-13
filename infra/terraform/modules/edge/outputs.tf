output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.frontend.id }
output "cloudfront_domain_name" { value = aws_cloudfront_distribution.frontend.domain_name }
output "assets_cloudfront_distribution_id" { value = aws_cloudfront_distribution.assets.id }
output "assets_cloudfront_domain_name" { value = aws_cloudfront_distribution.assets.domain_name }
output "alb_waf_arn" { value = try(aws_wafv2_web_acl.alb[0].arn, null) }
