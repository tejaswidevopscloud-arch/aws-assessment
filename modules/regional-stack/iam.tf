# -----------------------------------------------------
# IAM Roles & Policies – least-privilege
# -----------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# =====================================================
# Lambda Greeter Role
# =====================================================
resource "aws_iam_role" "greeter" {
  name               = "${var.project_name}-greeter-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = { Name = "${var.project_name}-greeter-role-${var.region}" }
}

data "aws_iam_policy_document" "greeter" {
  # CloudWatch Logs
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  # DynamoDB – PutItem on the regional table
  statement {
    sid       = "DynamoDB"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.greeting_logs.arn]
  }

  # SNS – publish to the Unleash live verification topic
  statement {
    sid       = "SNS"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }
}

resource "aws_iam_role_policy" "greeter" {
  name   = "greeter-policy"
  role   = aws_iam_role.greeter.id
  policy = data.aws_iam_policy_document.greeter.json
}

# =====================================================
# Lambda Dispatcher Role
# =====================================================
resource "aws_iam_role" "dispatcher" {
  name               = "${var.project_name}-dispatcher-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = { Name = "${var.project_name}-dispatcher-role-${var.region}" }
}

data "aws_iam_policy_document" "dispatcher" {
  # CloudWatch Logs
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  # ECS RunTask
  statement {
    sid       = "ECSRunTask"
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.sns_publisher.arn]
  }

  # PassRole so ECS can assume execution & task roles
  statement {
    sid     = "PassRole"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_execution.arn,
      aws_iam_role.ecs_task.arn,
    ]
  }
}

resource "aws_iam_role_policy" "dispatcher" {
  name   = "dispatcher-policy"
  role   = aws_iam_role.dispatcher.id
  policy = data.aws_iam_policy_document.dispatcher.json
}

# =====================================================
# ECS Execution Role (pull images, push logs)
# =====================================================
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project_name}-ecs-exec-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = { Name = "${var.project_name}-ecs-exec-role-${var.region}" }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" #tfsec:ignore:aws-iam-no-policy-wildcards
}

data "aws_caller_identity" "current" {}

# =====================================================
# ECS Task Role (SNS publish)
# =====================================================
resource "aws_iam_role" "ecs_task" {
  name               = "${var.project_name}-ecs-task-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = { Name = "${var.project_name}-ecs-task-role-${var.region}" }
}

data "aws_iam_policy_document" "ecs_task" {
  statement {
    sid       = "SNS"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task" {
  name   = "ecs-task-sns-policy"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task.json
}
