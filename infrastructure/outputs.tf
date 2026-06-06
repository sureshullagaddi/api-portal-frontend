output "gui_url" {
  description = "Open this URL in your browser to use the portal"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "s3_bucket_name" {
  description = "S3 bucket hosting the React app"
  value       = aws_s3_bucket.frontend.id
}

output "backend_api_url" {
  description = "Backend API URL (read from SSM)"
  value       = data.aws_ssm_parameter.backend_api_url.value
  sensitive   = true
}
