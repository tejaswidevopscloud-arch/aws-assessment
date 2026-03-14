# -----------------------------------------------------
# Root Variables
# -----------------------------------------------------

variable "project_name" {
  description = "Prefix used for all resource names"
  type        = string
  default     = "unleash-assessment"
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "email" {
  description = "Email address for the Cognito test user and SNS payloads"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository URL included in SNS payloads"
  type        = string
}

variable "sns_topic_arn" {
  description = "Unleash live Candidate-Verification SNS topic ARN (us-east-1)"
  type        = string
  default     = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
}

variable "cognito_user_password" {
  description = "Permanent password for the Cognito test user"
  type        = string
  sensitive   = true
  default     = "Assessment@2024!"
}
