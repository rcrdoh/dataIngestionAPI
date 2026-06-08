output "create_function_arn" {
  description = "ARN of the Create Lambda function"
  value       = aws_lambda_function.create_function.arn
}

output "read_function_arn" {
  description = "ARN of the Read Lambda function"
  value       = aws_lambda_function.read_function.arn
}

output "update_function_arn" {
  description = "ARN of the Update Lambda function"
  value       = aws_lambda_function.update_function.arn
}

output "delete_function_arn" {
  description = "ARN of the Delete Lambda function"
  value       = aws_lambda_function.delete_function.arn
}

output "auth_function_arn" {
  description = "ARN of the Auth Lambda function"
  value       = aws_lambda_function.auth_function.arn
}

output "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda functions"
  value       = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
}

output "departments_upload_function_arn" {
  description = "ARN of the Departments CSV upload Lambda function"
  value       = aws_lambda_function.csv_upload_functions["departments"].arn
}

output "jobs_upload_function_arn" {
  description = "ARN of the Jobs CSV upload Lambda function"
  value       = aws_lambda_function.csv_upload_functions["jobs"].arn
}

output "hired_employees_upload_function_arn" {
  description = "ARN of the Hired Employees CSV upload Lambda function"
  value       = aws_lambda_function.csv_upload_functions["hired_employees"].arn
}

output "backup_function_arn" {
  description = "ARN of the Backup Lambda function"
  value       = aws_lambda_function.backup_function.arn
}

output "restore_function_arn" {
  description = "ARN of the Restore Lambda function"
  value       = aws_lambda_function.restore_function.arn
}

output "backup_bucket_name" {
  description = "Name of the S3 backup bucket"
  value       = aws_s3_bucket.backup_bucket.id
}

output "backup_bucket_arn" {
  description = "ARN of the S3 backup bucket"
  value       = aws_s3_bucket.backup_bucket.arn
}