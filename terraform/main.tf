terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }

  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
# first DynamoDB table with plants API 
resource "aws_dynamodb_table" "plants" {
  name         = "${var.project_name}-plants-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "species_id"

  attribute {
    name = "species_id"
    type = "S"
  }
  tags = local.common_tags

}


# druga tabela DynamoDB user_inventory Tutaj pojawia się coś nowego — dwa klucze:
# hash_key — klucz główny (partition key)
# range_key — klucz sortowania (sort key)

resource "aws_dynamodb_table" "user_inventory" {
  name         = "${var.project_name}-user-inventory-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "species_id"

  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "species_id"
    type = "S"
  }

  tags = local.common_tags
}

# trzecia tabela DynamoDB garden_tasks 

resource "aws_dynamodb_table" "garden_tasks" {
  name         = "${var.project_name}-garden-tasks-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "task_id"

  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "task_id"
    type = "S"
  }

  tags = local.common_tags
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags

}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ssm" {
  name   = "${var.project_name}-lambda-ssm-policy-role-${var.environment}"
  role   = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/plant-app/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "${var.project_name}-lambda-dynamodb-policy-role-${var.environment}"
  role   = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem","dynamodb:GetItem"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-plants-${var.environment}"
      }
    ]
  })
}

data "archive_file" "translate_plant_name" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/translate_plant_name"
  output_path = "${path.module}/translate_plant_name.zip"
}

data "archive_file" "fetch_plant_data" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/fetch_plant_data"
  output_path = "${path.module}/fetch_plant_data.zip"
}


resource "aws_lambda_function" "translate_plant_name" {
  filename         = data.archive_file.translate_plant_name.output_path
  function_name    = "${var.project_name}-translate-plant-name-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.translate_plant_name.output_base64sha256
  timeout          = 30  
  tags = local.common_tags
}


resource "aws_lambda_function" "fetch_plant_data" {
  filename         = data.archive_file.fetch_plant_data.output_path
  function_name    = "${var.project_name}-fetch-plant-data-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.fetch_plant_data.output_base64sha256
  timeout          = 30  # 30 sekund — wystarczy dla zewnętrznych API
  environment {
    variables = {
      DYNAMODB_TABLE_PLANTS = aws_dynamodb_table.plants.name
    }
  }

  tags = local.common_tags
}

resource "aws_api_gateway_rest_api" "plant_api" {
  name        = "${var.project_name}-plant-api-${var.environment}"
  description = "API Gateway for plant application"

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "plants" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  parent_id   = aws_api_gateway_rest_api.plant_api.root_resource_id
  path_part   = "plants"
}

resource "aws_api_gateway_resource" "translate" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  parent_id   = aws_api_gateway_rest_api.plant_api.root_resource_id
  path_part   = "translate"
}

resource "aws_api_gateway_method" "plants_post" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.plants.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "translate_post" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.translate.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "plants_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.plants.id
  http_method             = aws_api_gateway_method.plants_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.fetch_plant_data.invoke_arn
}

resource "aws_api_gateway_integration" "translate_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.translate.id
  http_method             = aws_api_gateway_method.translate_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.translate_plant_name.invoke_arn
}

resource "aws_api_gateway_deployment" "plant_api" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.plants_integration,
      aws_api_gateway_integration.translate_integration,
      aws_api_gateway_integration.generate_plan_integration
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.plants_integration,
    aws_api_gateway_integration.translate_integration,
    aws_api_gateway_integration.generate_plan_integration
  ]
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.plant_api.id
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  stage_name    = var.environment
}

resource "aws_lambda_permission" "plants_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_plant_data.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "translate_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translate_plant_name.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}

data "archive_file" "generate_garden_plan" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/generate_garden_plan"
  output_path = "${path.module}/generate_garden_plan.zip"
}

resource "aws_lambda_function" "generate_garden_plan" {
  filename         = data.archive_file.generate_garden_plan.output_path
  function_name    = "${var.project_name}-generate-garden-plan-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.generate_garden_plan.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_GARDEN_TASKS = aws_dynamodb_table.garden_tasks.name
    }
  }

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "generate_plan" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  parent_id   = aws_api_gateway_rest_api.plant_api.root_resource_id
  path_part   = "generate-plan"
}

resource "aws_api_gateway_method" "generate_plan_post" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.generate_plan.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "generate_plan_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.generate_plan.id
  http_method             = aws_api_gateway_method.generate_plan_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.generate_garden_plan.invoke_arn
}

resource "aws_lambda_permission" "generate_plan_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_garden_plan.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}

