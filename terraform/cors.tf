# CORS configuration for all API Gateway endpoints
# Each endpoint needs: OPTIONS method + MOCK integration + method response + integration response

locals {
  cors_headers = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PATCH,OPTIONS,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  cors_response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# ─── /tasks CORS ───────────────────────────────────────────────────────────────

resource "aws_api_gateway_method" "tasks_options" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.get_tasks.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "tasks_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.get_tasks.id
  http_method = aws_api_gateway_method.tasks_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "tasks_options_200" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.get_tasks.id
  http_method = aws_api_gateway_method.tasks_options.http_method
  status_code = "200"
  response_parameters = local.cors_response_parameters
}

resource "aws_api_gateway_integration_response" "tasks_options_response" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.get_tasks.id
  http_method = aws_api_gateway_method.tasks_options.http_method
  status_code = "200"
  response_parameters = local.cors_headers
  depends_on  = [aws_api_gateway_integration.tasks_options_integration]
}

# ─── /inventory CORS ───────────────────────────────────────────────────────────

resource "aws_api_gateway_method" "inventory_options" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.inventory.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "inventory_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.inventory.id
  http_method = aws_api_gateway_method.inventory_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "inventory_options_200" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.inventory.id
  http_method = aws_api_gateway_method.inventory_options.http_method
  status_code = "200"
  response_parameters = local.cors_response_parameters
}

resource "aws_api_gateway_integration_response" "inventory_options_response" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.inventory.id
  http_method = aws_api_gateway_method.inventory_options.http_method
  status_code = "200"
  response_parameters = local.cors_headers
  depends_on  = [aws_api_gateway_integration.inventory_options_integration]
}

# ─── /users CORS ───────────────────────────────────────────────────────────────

resource "aws_api_gateway_method" "users_options" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "users_options_200" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_options.http_method
  status_code = "200"
  response_parameters = local.cors_response_parameters
}

resource "aws_api_gateway_integration_response" "users_options_response" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_options.http_method
  status_code = "200"
  response_parameters = local.cors_headers
  depends_on  = [aws_api_gateway_integration.users_options_integration]
}

# ─── /plants CORS ──────────────────────────────────────────────────────────────

resource "aws_api_gateway_method" "plants_options" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.plants.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "plants_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.plants.id
  http_method = aws_api_gateway_method.plants_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "plants_options_200" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.plants.id
  http_method = aws_api_gateway_method.plants_options.http_method
  status_code = "200"
  response_parameters = local.cors_response_parameters
}

resource "aws_api_gateway_integration_response" "plants_options_response" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.plants.id
  http_method = aws_api_gateway_method.plants_options.http_method
  status_code = "200"
  response_parameters = local.cors_headers
  depends_on  = [aws_api_gateway_integration.plants_options_integration]
}

# ─── /generate-plan CORS ───────────────────────────────────────────────────────

resource "aws_api_gateway_method" "generate_plan_options" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.generate_plan.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "generate_plan_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.generate_plan.id
  http_method = aws_api_gateway_method.generate_plan_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "generate_plan_options_200" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.generate_plan.id
  http_method = aws_api_gateway_method.generate_plan_options.http_method
  status_code = "200"
  response_parameters = local.cors_response_parameters
}

resource "aws_api_gateway_integration_response" "generate_plan_options_response" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.generate_plan.id
  http_method = aws_api_gateway_method.generate_plan_options.http_method
  status_code = "200"
  response_parameters = local.cors_headers
  depends_on  = [aws_api_gateway_integration.generate_plan_options_integration]
}

# ─── /suggest-options CORS ───────────────────────────────────────────────────────


resource "aws_api_gateway_method" "suggest_options" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.suggest.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "suggest_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.suggest.id
  http_method = aws_api_gateway_method.suggest_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "suggest_options_200" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.suggest.id
  http_method = aws_api_gateway_method.suggest_options.http_method
  status_code = "200"
  response_parameters = local.cors_response_parameters
}

resource "aws_api_gateway_integration_response" "suggest_options_response" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  resource_id = aws_api_gateway_resource.suggest.id
  http_method = aws_api_gateway_method.suggest_options.http_method
  status_code = "200"
  response_parameters = local.cors_headers
  depends_on  = [aws_api_gateway_integration.suggest_options_integration]
}