data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  resize_image_source_dir = "${path.module}/lambda/resize-image"
  resize_image_zip_path   = "${path.module}/build/resize-image.zip"
}

data "archive_file" "resize_image" {
  type        = "zip"
  source_dir  = local.resize_image_source_dir
  output_path = local.resize_image_zip_path
}

resource "aws_cloudwatch_log_group" "resize_image" {
  name              = "/aws/lambda/${var.name_prefix}-resize-image"
  retention_in_days = 14
}

resource "aws_iam_role" "resize_image" {
  name = "${var.name_prefix}-resize-image-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "resize_image" {
  name = "${var.name_prefix}-resize-image-policy"
  role = aws_iam_role.resize_image.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.resize_image.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.user_asset_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.user_asset_bucket_arn}/resized/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_lambda_function" "resize_image" {
  function_name                  = "${var.name_prefix}-resize-image"
  role                           = aws_iam_role.resize_image.arn
  runtime                        = "nodejs20.x"
  handler                        = "index.handler"
  filename                       = data.archive_file.resize_image.output_path
  source_code_hash               = data.archive_file.resize_image.output_base64sha256
  timeout                        = 30
  memory_size                    = 512
  reserved_concurrent_executions = var.resize_image_reserved_concurrency

  environment {
    variables = {
      USER_ASSET_BUCKET = var.user_asset_bucket_id
      OUTPUT_PREFIX     = "resized"
    }
  }

  depends_on = [aws_cloudwatch_log_group.resize_image]
}

resource "aws_api_gateway_rest_api" "resize_image" {
  name        = "${var.name_prefix}-resize-image-api"
  description = "MH4 API Gateway surface for Lambda image resizing."

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "resize_image" {
  rest_api_id = aws_api_gateway_rest_api.resize_image.id
  parent_id   = aws_api_gateway_rest_api.resize_image.root_resource_id
  path_part   = "resize-image"
}

resource "aws_api_gateway_method" "resize_image_post" {
  rest_api_id      = aws_api_gateway_rest_api.resize_image.id
  resource_id      = aws_api_gateway_resource.resize_image.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "resize_image_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.resize_image.id
  resource_id             = aws_api_gateway_resource.resize_image.id
  http_method             = aws_api_gateway_method.resize_image_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.resize_image.invoke_arn
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resize_image.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.resize_image.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "resize_image" {
  rest_api_id = aws_api_gateway_rest_api.resize_image.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.resize_image.id,
      aws_api_gateway_method.resize_image_post.id,
      aws_api_gateway_integration.resize_image_lambda.id,
      aws_lambda_function.resize_image.source_code_hash
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.resize_image_lambda,
    aws_lambda_permission.allow_api_gateway
  ]
}

resource "aws_api_gateway_stage" "resize_image" {
  rest_api_id   = aws_api_gateway_rest_api.resize_image.id
  deployment_id = aws_api_gateway_deployment.resize_image.id
  stage_name    = "prod"
}

resource "aws_api_gateway_api_key" "resize_image" {
  name = "${var.name_prefix}-resize-image-key"
}

resource "aws_api_gateway_usage_plan" "resize_image" {
  name = "${var.name_prefix}-resize-image-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.resize_image.id
    stage  = aws_api_gateway_stage.resize_image.stage_name
  }

  throttle_settings {
    rate_limit  = var.resize_image_rate_limit
    burst_limit = var.resize_image_burst_limit
  }
}

resource "aws_api_gateway_usage_plan_key" "resize_image" {
  key_id        = aws_api_gateway_api_key.resize_image.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.resize_image.id
}
