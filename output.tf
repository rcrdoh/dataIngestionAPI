output "api_endpoint" {
  description = "API Gateway invoke URL"
  value       = module.crud.api_gateway_invoke_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.crud.cognito_user_pool_id
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.crud.cognito_user_pool_client_id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.crud.dynamodb_table_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for static website"
  value       = module.crud.s3_bucket_name
}

output "s3_website_url" {
  description = "S3 website URL"
  value       = "http://${module.crud.s3_bucket_name}.s3-website-${var.aws_region}.amazonaws.com"
}
