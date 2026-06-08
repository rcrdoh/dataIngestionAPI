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
  description = "Name of the DynamoDB table"
  type        = string
  default     = "CrudTable"
}

variable "user_pool_name" {
  description = "Name of the Cognito user pool"
  type        = string
  default     = "SimpleCrudUserPool"
}

variable "aws_region" {
  description = "AWS region for the Lambda functions"
  type        = string
}

# ---------------------------------------------------------------------------
# RDS / PostgreSQL variables
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