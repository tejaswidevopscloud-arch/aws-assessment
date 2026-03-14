variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "email" {
  description = "Email address for the test user"
  type        = string
}

variable "cognito_user_password" {
  description = "Permanent password for the Cognito test user"
  type        = string
  sensitive   = true
}
