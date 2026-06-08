# Lambda functions module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# IAM Role for Lambda functions (if not provided externally)
resource "aws_iam_role" "lambda_role" {
  count = var.lambda_role_arn == "" ? 1 : 0
  name  = "${replace(var.project_name, " ", "")}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}LambdaRole${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

# IAM Policy for Lambda (DynamoDB access)
resource "aws_iam_role_policy" "lambda_policy" {
  count = var.lambda_role_arn == "" ? 1 : 0
  name  = "${var.project_name}-lambda-policy-${var.environment}"
  role  = var.lambda_role_arn == "" ? aws_iam_role.lambda_role[0].id : replace(var.lambda_role_arn, "/.*/", var.project_name)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.table_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:InitiateAuth",
          "cognito-idp:RespondToAuthChallenge",
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:AdminRespondToAuthChallenge"
        ]
        Resource = "arn:aws:cognito-idp:*:*:userpool/${var.user_pool_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.backup_bucket.arn,
          "${aws_s3_bucket.backup_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Functions
resource "aws_lambda_function" "create_function" {
  function_name    = "${var.project_name}-create-${var.environment}"
  runtime          = "python3.11"
  handler          = "create.lambda_handler"
  role             = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
  filename         = "${path.module}/../lambda_code/create.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_code/create.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}CreateFunction${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

resource "aws_lambda_function" "read_function" {
  function_name    = "${var.project_name}-read-${var.environment}"
  runtime          = "python3.11"
  handler          = "read.lambda_handler"
  role             = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
  filename         = "${path.module}/../lambda_code/read.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_code/read.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}ReadFunction${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

resource "aws_lambda_function" "update_function" {
  function_name    = "${var.project_name}-update-${var.environment}"
  runtime          = "python3.11"
  handler          = "update.lambda_handler"
  role             = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
  filename         = "${path.module}/../lambda_code/update.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_code/update.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}UpdateFunction${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

resource "aws_lambda_function" "delete_function" {
  function_name    = "${var.project_name}-delete-${var.environment}"
  runtime          = "python3.11"
  handler          = "delete.lambda_handler"
  role             = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
  filename         = "${path.module}/../lambda_code/delete.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_code/delete.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}DeleteFunction${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

resource "aws_lambda_function" "auth_function" {
  function_name    = "${var.project_name}-auth-${var.environment}"
  runtime          = "python3.11"
  handler          = "auth.lambda_handler"
  role             = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
  filename         = "${path.module}/../lambda_code/auth.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_code/auth.zip")
  timeout          = 10

  environment {
    variables = {
      USER_POOL_ID = var.user_pool_id
      CLIENT_ID    = var.user_pool_client_id
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}AuthFunction${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

# ---------------------------------------------------------------------------
# CSV Upload Lambda Functions (products, customers, orders)
# ---------------------------------------------------------------------------
locals {
  csv_upload_functions = {
    departments      = "departments_upload"
    jobs             = "jobs_upload"
    hired_employees  = "hired_employees_upload"
  }
}

resource "aws_lambda_function" "csv_upload_functions" {
  for_each = local.csv_upload_functions

  function_name    = "${var.project_name}-${each.key}-upload-${var.environment}"
  runtime          = "python3.11"
  handler          = "${each.value}.lambda_handler"
  role             = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
  filename         = "${path.module}/../lambda_code/${each.value}.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_code/${each.value}.zip")
  timeout          = 120

  environment {
    variables = {
      TABLE_NAME  = var.table_name
      DB_HOST     = var.db_host
      DB_PORT     = var.db_port
      DB_NAME     = var.db_name
      DB_USER     = var.db_user
      DB_PASSWORD = var.db_password
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}${title(each.key)}UploadFunction${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

# ===========================================================================
# Backup S3 bucket — stores AVRO backups under backups/<id>/<table>.avro
# ===========================================================================
resource "random_id" "backup_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "backup_bucket" {
  bucket = "${lower(var.project_name)}-${var.environment}-backups-${random_id.backup_suffix.hex}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}BackupBucket${title(var.environment)}"
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

resource "aws_s3_bucket_versioning" "backup_versioning" {
  bucket = aws_s3_bucket.backup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup_encryption" {
  bucket = aws_s3_bucket.backup_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup_public_access" {
  bucket = aws_s3_bucket.backup_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ===========================================================================
# Backup & Restore Lambda Functions
# ===========================================================================
resource "aws_lambda_function" "backup_function" {
  function_name    = "${var.project_name}-backup-${var.environment}"
  runtime          = "python3.11"
  handler          = "backup.lambda_handler"
  role             = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
  filename         = "${path.module}/../lambda_code/backup.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_code/backup.zip")
  timeout          = 120

  environment {
    variables = {
      TABLE_NAME    = var.table_name
      DB_HOST       = var.db_host
      DB_PORT       = var.db_port
      DB_NAME       = var.db_name
      DB_USER       = var.db_user
      DB_PASSWORD   = var.db_password
      BACKUP_BUCKET = aws_s3_bucket.backup_bucket.id
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}BackupFunction${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}

resource "aws_lambda_function" "restore_function" {
  function_name    = "${var.project_name}-restore-${var.environment}"
  runtime          = "python3.11"
  handler          = "restore.lambda_handler"
  role             = var.lambda_role_arn != "" ? var.lambda_role_arn : aws_iam_role.lambda_role[0].arn
  filename         = "${path.module}/../lambda_code/restore.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_code/restore.zip")
  timeout          = 120

  environment {
    variables = {
      TABLE_NAME    = var.table_name
      DB_HOST       = var.db_host
      DB_PORT       = var.db_port
      DB_NAME       = var.db_name
      DB_USER       = var.db_user
      DB_PASSWORD   = var.db_password
      BACKUP_BUCKET = aws_s3_bucket.backup_bucket.id
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}RestoreFunction${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}