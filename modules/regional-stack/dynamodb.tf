# -----------------------------------------------------
# DynamoDB – regional GreetingLogs table
# PAY_PER_REQUEST = cost-optimized (no idle capacity)
# -----------------------------------------------------

resource "aws_dynamodb_table" "greeting_logs" {
  name         = "GreetingLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-greeting-logs-${var.region}"
  }
}
