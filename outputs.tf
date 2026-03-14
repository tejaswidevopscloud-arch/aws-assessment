# -----------------------------------------------------
# Root Outputs
# -----------------------------------------------------

# Cognito
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.cognito.user_pool_client_id
}

# API Gateway endpoints
output "api_url_us_east_1" {
  description = "API Gateway invoke URL – us-east-1"
  value       = module.regional_us_east_1.api_url
}

output "api_url_eu_west_1" {
  description = "API Gateway invoke URL – eu-west-1"
  value       = module.regional_eu_west_1.api_url
}
