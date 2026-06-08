# Bootstrap: Creates S3 bucket + DynamoDB table for Terraform remote state
#
# This must be applied ONCE before the root project switches to the S3 backend.
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply
#
# After apply, note the outputs (bucket name, table name, region) and pass
# them to the root project via backend-config:
#   cd ..
#   terraform init -migrate-state \
#     -backend-config="bucket=$(cd bootstrap && terraform output -raw state_bucket_name)" \
#     -backend-config="dynamodb_table=$(cd bootstrap && terraform output -raw state_lock_table_name)" \
#     -backend-config="region=$(cd bootstrap && terraform output -raw aws_region)"

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Purpose   = "terraform-state-bootstrap"
    }
  }
}

# -----------------------------------------------------------------------------
# S3 bucket for Terraform state
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.project_name}-terraform-state"
  }
}

# Versioning — keep history of state files for rollback
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# DynamoDB table for state locking
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.state_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-terraform-lock"
  }
}
