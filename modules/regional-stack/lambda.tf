# -----------------------------------------------------
# Lambda Functions – Greeter & Dispatcher
# -----------------------------------------------------

# ---------- Zip the source code ----------
data "archive_file" "greeter" {
  type        = "zip"
  source_file = "${path.root}/lambdas/greeter/index.py"
  output_path = "${path.root}/lambdas/greeter/greeter.zip"
}

data "archive_file" "dispatcher" {
  type        = "zip"
  source_file = "${path.root}/lambdas/dispatcher/index.py"
  output_path = "${path.root}/lambdas/dispatcher/dispatcher.zip"
}

# ---------- CloudWatch Log Groups ----------
resource "aws_cloudwatch_log_group" "greeter" {
  name              = "/aws/lambda/${var.project_name}-greeter-${var.region}"
  retention_in_days = 7

  tags = { Name = "${var.project_name}-greeter-logs-${var.region}" }
}

resource "aws_cloudwatch_log_group" "dispatcher" {
  name              = "/aws/lambda/${var.project_name}-dispatcher-${var.region}"
  retention_in_days = 7

  tags = { Name = "${var.project_name}-dispatcher-logs-${var.region}" }
}

# ---------- Greeter Lambda ----------
resource "aws_lambda_function" "greeter" {
  function_name    = "${var.project_name}-greeter-${var.region}"
  role             = aws_iam_role.greeter.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.greeter.output_path
  source_code_hash = data.archive_file.greeter.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.greeting_logs.name
      SNS_TOPIC_ARN  = var.sns_topic_arn
      EMAIL          = var.email
      GITHUB_REPO    = var.github_repo
    }
  }

  depends_on = [
    aws_iam_role_policy.greeter,
    aws_cloudwatch_log_group.greeter,
  ]

  tags = { Name = "${var.project_name}-greeter-${var.region}" }
}

# ---------- Dispatcher Lambda ----------
resource "aws_lambda_function" "dispatcher" {
  function_name    = "${var.project_name}-dispatcher-${var.region}"
  role             = aws_iam_role.dispatcher.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.dispatcher.output_path
  source_code_hash = data.archive_file.dispatcher.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER_ARN     = aws_ecs_cluster.main.arn
      ECS_TASK_DEFINITION = aws_ecs_task_definition.sns_publisher.arn
      SUBNETS             = join(",", aws_subnet.public[*].id)
      SECURITY_GROUP      = aws_security_group.ecs.id
      CONTAINER_NAME      = "sns-publisher"
    }
  }

  depends_on = [
    aws_iam_role_policy.dispatcher,
    aws_cloudwatch_log_group.dispatcher,
  ]

  tags = { Name = "${var.project_name}-dispatcher-${var.region}" }
}
