terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend — values populated by the bootstrap module.
  # Run `terraform init` with -backend-config flags (see README.md).
  backend "s3" {
    key     = "bootstrap/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

module "crud" {
  source = "./modules/crud"

  environment    = var.environment
  project_name   = var.project_name
  aws_region     = var.aws_region
  table_name     = var.table_name
  user_pool_name = var.user_pool_name

  # RDS / PostgreSQL
  db_host     = var.db_host
  db_port     = var.db_port
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password

  common_tags = var.common_tags
}
