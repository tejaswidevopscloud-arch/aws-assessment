# -----------------------------------------------------
# Regional-stack module – variables
# -----------------------------------------------------

variable "region" {
  description = "AWS region this stack is deployed into"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "email" {
  description = "Email for SNS payloads"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository URL for SNS payloads"
  type        = string
}

variable "sns_topic_arn" {
  description = "Unleash live SNS topic ARN (us-east-1)"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID (us-east-1)"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  type        = string
}
