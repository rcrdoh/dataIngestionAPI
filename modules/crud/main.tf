# CRUD module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "dynamodb" {
  source = "./dynamodb"

  environment  = var.environment
  project_name = var.project_name
  table_name   = var.table_name

  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Tier        = "datastore"
  })
}

module "cognito" {
  source = "./cognito"

  environment     = var.environment
  project_name    = var.project_name
  user_pool_name  = var.user_pool_name

  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Tier        = "authentication"
  })
}

module "lambda" {
  source = "./lambda"

  environment      = var.environment
  project_name     = var.project_name
  table_name       = module.dynamodb.table_name
  user_pool_id     = module.cognito.user_pool_id
  user_pool_client_id = module.cognito.user_pool_client_id

  # RDS / PostgreSQL
  db_host     = var.db_host
  db_port     = var.db_port
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password

  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Tier        = "compute"
  })
}

module "s3" {
  source = "./s3"

  environment  = var.environment
  project_name = var.project_name

  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Tier        = "storage"
  })
}

module "api_gateway" {
  source = "./apigatewayv2"

  environment             = var.environment
  project_name            = var.project_name
  aws_region              = var.aws_region
  cognito_user_pool_arn   = module.cognito.user_pool_arn
  create_function_arn     = module.lambda.create_function_arn
  read_function_arn       = module.lambda.read_function_arn
  update_function_arn     = module.lambda.update_function_arn
  delete_function_arn     = module.lambda.delete_function_arn
  auth_function_arn            = module.lambda.auth_function_arn
  departments_upload_function_arn      = module.lambda.departments_upload_function_arn
  jobs_upload_function_arn             = module.lambda.jobs_upload_function_arn
  hired_employees_upload_function_arn  = module.lambda.hired_employees_upload_function_arn
  backup_function_arn                  = module.lambda.backup_function_arn
  restore_function_arn                 = module.lambda.restore_function_arn

  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Tier        = "networking"
  })
}