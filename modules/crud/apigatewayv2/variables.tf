variable "environment" {
  description = "The environment name (dev/qa/prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project used for resource naming"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "api_gateway_name" {
  description = "Name of the API Gateway REST API"
  type        = string
  default     = "CrudApi"
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool for authentication"
  type        = string
  default     = ""
}

variable "auth_function_arn" {
  description = "ARN of the Auth Lambda function"
  type        = string
}

variable "departments_upload_function_arn" {
  description = "ARN of the Departments CSV upload Lambda function"
  type        = string
}

variable "jobs_upload_function_arn" {
  description = "ARN of the Jobs CSV upload Lambda function"
  type        = string
}

variable "hired_employees_upload_function_arn" {
  description = "ARN of the Hired Employees CSV upload Lambda function"
  type        = string
}

variable "backup_function_arn" {
  description = "ARN of the Backup Lambda function"
  type        = string
}

variable "restore_function_arn" {
  description = "ARN of the Restore Lambda function"
  type        = string
}

variable "hiring_quarterly_function_arn" {
  description = "ARN of the Hiring Quarterly report Lambda function"
  type        = string
}

variable "top_departments_function_arn" {
  description = "ARN of the Top Departments report Lambda function"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the Lambda functions"
  type        = string
}