# -----------------------------------------------------
# Root Module – wires Cognito + two regional stacks
# -----------------------------------------------------

# =====================================================
# 1. Authentication – Cognito (us-east-1 only)
# =====================================================
module "cognito" {
  source = "./modules/cognito"

  project_name          = var.project_name
  environment           = var.environment
  email                 = var.email
  cognito_user_password = var.cognito_user_password
}

# =====================================================
# 2a. Regional stack – us-east-1
# =====================================================
module "regional_us_east_1" {
  source = "./modules/regional-stack"

  region                      = "us-east-1"
  project_name                = var.project_name
  environment                 = var.environment
  email                       = var.email
  github_repo                 = var.github_repo
  sns_topic_arn               = var.sns_topic_arn
  cognito_user_pool_id        = module.cognito.user_pool_id
  cognito_user_pool_arn       = module.cognito.user_pool_arn
  cognito_user_pool_client_id = module.cognito.user_pool_client_id
}

# =====================================================
# 2b. Regional stack – eu-west-1
# =====================================================
module "regional_eu_west_1" {
  source = "./modules/regional-stack"

  providers = {
    aws = aws.eu_west_1
  }

  region                      = "eu-west-1"
  project_name                = var.project_name
  environment                 = var.environment
  email                       = var.email
  github_repo                 = var.github_repo
  sns_topic_arn               = var.sns_topic_arn
  cognito_user_pool_id        = module.cognito.user_pool_id
  cognito_user_pool_arn       = module.cognito.user_pool_arn
  cognito_user_pool_client_id = module.cognito.user_pool_client_id
}
