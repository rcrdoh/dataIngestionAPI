# S3 module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Random suffix for unique S3 bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket configured for website hosting
resource "aws_s3_bucket" "crud_website" {
  bucket = "${lower(var.project_name)}-${var.environment}-website-${random_id.bucket_suffix.hex}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${replace(var.project_name, " ", "")}Website${title(var.environment)}"
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# Enable website hosting for the bucket
resource "aws_s3_bucket_website_configuration" "crud_website_config" {
  bucket = aws_s3_bucket.crud_website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Upload the static files to the bucket
resource "aws_s3_object" "website_files" {
  for_each = fileset("${path.module}/../../../static/", "**")

  bucket       = aws_s3_bucket.crud_website.id
  key          = each.value
  source       = "${path.module}/../../../static/${each.value}"
  etag         = filemd5("${path.module}/../../../static/${each.value}")
  content_type = lookup({
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
  }, regex("\\.[^.]+$", each.value), "binary/octet-stream")

  depends_on = [aws_s3_bucket_public_access_block.crud_website]
}

# Allow public access for website hosting
resource "aws_s3_bucket_public_access_block" "crud_website" {
  bucket = aws_s3_bucket.crud_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Ownership controls required for website hosting with AWS provider ~> 5.0
resource "aws_s3_bucket_ownership_controls" "crud_website" {
  bucket = aws_s3_bucket.crud_website.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Enable ACLs for website hosting
resource "aws_s3_bucket_acl" "crud_website" {
  bucket = aws_s3_bucket.crud_website.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket_public_access_block.crud_website,
    aws_s3_bucket_ownership_controls.crud_website,
  ]
}

# Bucket policy granting public read access for website hosting
resource "aws_s3_bucket_policy" "crud_website" {
  bucket = aws_s3_bucket.crud_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.crud_website.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.crud_website
  ]
}