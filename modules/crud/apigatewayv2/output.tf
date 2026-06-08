output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.crud_api.id
}

output "api_gateway_root_resource_id" {
  description = "Root resource ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.crud_api.root_resource_id
}

output "invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.prod.invoke_url
}