# DynamoDB module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "crud_table" {
  name         = "${var.table_name}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}DynamoDBTable${title(var.environment)}"
      Environment = var.environment
      Project     = replace(var.project_name, " ", "_")
    }
  )
}