output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.crud_website.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.crud_website.arn
}

output "website_domain" {
  description = "Domain name of the website"
  value       = aws_s3_bucket_website_configuration.crud_website_config.website_endpoint
}

output "website_url" {
  description = "Website URL"
  value       = "http://${aws_s3_bucket_website_configuration.crud_website_config.website_endpoint}"
}