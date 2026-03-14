# -----------------------------------------------------
# API Gateway (HTTP API) + Cognito JWT Authorizer
# -----------------------------------------------------

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api-${var.region}"
  protocol_type = "HTTP"

  tags = { Name = "${var.project_name}-api-${var.region}" }
}

# ---------- JWT Authorizer (Cognito us-east-1) ----------
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt"

  jwt_configuration {
    audience = [var.cognito_user_pool_client_id]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

# ---------- Integrations ----------
resource "aws_apigatewayv2_integration" "greet" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.greeter.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "dispatch" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.dispatcher.invoke_arn
  payload_format_version = "2.0"
}

# ---------- Routes ----------
resource "aws_apigatewayv2_route" "greet" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /greet"
  target             = "integrations/${aws_apigatewayv2_integration.greet.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "dispatch" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /dispatch"
  target             = "integrations/${aws_apigatewayv2_integration.dispatch.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# ---------- Default Stage (auto-deploy) ----------
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = { Name = "${var.project_name}-api-stage-${var.region}" }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${var.project_name}-${var.region}"
  retention_in_days = 7

  tags = { Name = "${var.project_name}-apigw-logs-${var.region}" }
}

# ---------- Lambda Permissions for API Gateway ----------
resource "aws_lambda_permission" "greet" {
  statement_id  = "AllowAPIGatewayInvokeGreet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "dispatch" {
  statement_id  = "AllowAPIGatewayInvokeDispatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatcher.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
