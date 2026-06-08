# Cognito module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Cognito User Pool
resource "aws_cognito_user_pool" "auth_pool" {
  name = "${var.user_pool_name}-${var.environment}"

  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  mfa_configuration = "OFF"

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}CognitoUserPool${title(var.environment)}"
      Environment = title(var.environment)
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "auth_client" {
  name         = "${var.user_pool_name}-${var.environment}-client"
  user_pool_id = aws_cognito_user_pool.auth_pool.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
}