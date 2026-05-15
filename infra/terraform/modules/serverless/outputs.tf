output "resize_image_api_url" {
  value = "${aws_api_gateway_stage.resize_image.invoke_url}/resize-image"
}

output "resize_image_api_key_value" {
  value     = aws_api_gateway_api_key.resize_image.value
  sensitive = true
}

output "resize_image_api_id" {
  value = aws_api_gateway_rest_api.resize_image.id
}

output "resize_image_lambda_name" {
  value = aws_lambda_function.resize_image.function_name
}

output "resize_image_usage_plan_id" {
  value = aws_api_gateway_usage_plan.resize_image.id
}
