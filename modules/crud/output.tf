output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.dynamodb.table_arn
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool"
  value       = module.cognito.user_pool_arn
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito user pool client"
  value       = module.cognito.user_pool_client_id
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.api_gateway_id
}

output "api_gateway_root_resource_id" {
  description = "Root resource ID of the API Gateway"
  value       = module.api_gateway.api_gateway_root_resource_id
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = module.api_gateway.invoke_url
}

output "lambda_role_arn" {
  description = "ARN of the Lambda role"
  value       = module.lambda.lambda_role_arn
}

output "lambda_auth_function_arn" {
  description = "ARN of the Auth Lambda function"
  value       = module.lambda.auth_function_arn
}

output "lambda_departments_upload_function_arn" {
  description = "ARN of the Departments CSV upload Lambda function"
  value       = module.lambda.departments_upload_function_arn
}

output "lambda_jobs_upload_function_arn" {
  description = "ARN of the Jobs CSV upload Lambda function"
  value       = module.lambda.jobs_upload_function_arn
}

output "lambda_hired_employees_upload_function_arn" {
  description = "ARN of the Hired Employees CSV upload Lambda function"
  value       = module.lambda.hired_employees_upload_function_arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.bucket_arn
}

output "backup_bucket_name" {
  description = "Name of the S3 backup bucket"
  value       = module.lambda.backup_bucket_name
}

output "lambda_backup_function_arn" {
  description = "ARN of the Backup Lambda function"
  value       = module.lambda.backup_function_arn
}

output "lambda_restore_function_arn" {
  description = "ARN of the Restore Lambda function"
  value       = module.lambda.restore_function_arn
}