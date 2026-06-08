variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev/qa/prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "SimpleCrud"
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

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Owner = "DevTeam"
  }
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
