# -----------------------------------------------------
# ECS Fargate – cost-optimized SNS publisher task
# -----------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.region}"

  setting {
    name  = "containerInsights"
    value = "disabled" # Cost optimization
  }

  tags = { Name = "${var.project_name}-cluster-${var.region}" }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.region}"
  retention_in_days = 7

  tags = { Name = "${var.project_name}-ecs-logs-${var.region}" }
}

resource "aws_ecs_task_definition" "sns_publisher" {
  family                   = "${var.project_name}-sns-publisher-${var.region}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256" # 0.25 vCPU – minimum cost
  memory                   = "512" # 0.5 GB   – minimum cost
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "sns-publisher"
      image     = "amazon/aws-cli:latest"
      essential = true
      command = [
        "sns", "publish",
        "--topic-arn", var.sns_topic_arn,
        "--region", "us-east-1",
        "--message", jsonencode({
          email  = var.email
          source = "ECS"
          region = var.region
          repo   = var.github_repo
        }),
        "--subject", "Candidate Verification - ECS - ${var.region}"
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-${var.region}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "${var.project_name}-sns-publisher-${var.region}" }
}

# ---------- Security Group (egress-only) ----------
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-ecs-"
  description = "ECS Fargate security group egress only"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-sg-${var.region}"
  }

  lifecycle {
    create_before_destroy = true
  }
}
