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

variable "table_name" {
  description = "Name of the DynamoDB table for environment"
  type        = string
}

variable "user_pool_id" {
  description = "ID of the Cognito user pool"
  type        = string
  default     = ""
}

variable "user_pool_client_id" {
  description = "ID of the Cognito user pool client"
  type        = string
  default     = ""
}

variable "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda functions, if provided"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# RDS / PostgreSQL variables (used by CSV upload Lambdas)
# ---------------------------------------------------------------------------
variable "db_host" {
  description = "PostgreSQL RDS endpoint hostname"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "PostgreSQL RDS port"
  type        = string
  default     = "5432"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "crud_db"
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  default     = ""
}