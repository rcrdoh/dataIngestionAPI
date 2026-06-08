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

variable "user_pool_name" {
  description = "Name of the Cognito user pool"
  type        = string
  default     = "SimpleCrudUserPool"
}