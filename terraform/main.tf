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
  backend "s3" {} 
}

provider "aws" {
  region = var.aws_region
}

locals {
  environment = terraform.workspace
  common_tags = {
    Environment = local.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
# first DynamoDB table with plants API 
resource "aws_dynamodb_table" "plants" {
  name         = "${var.project_name}-plants-${local.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "species_id"

  attribute {
    name = "species_id"
    type = "S"
  }

  attribute {
    name = "genus_name"
    type = "S"
  }

  global_secondary_index {
    name            = "genus_name-index"
    hash_key        = "genus_name"
    projection_type = "ALL"
  }

  tags = local.common_tags
}


# DynamoDB table user_inventory with two keys:
# hash_key — main key (partition key)
# range_key — sort key

resource "aws_dynamodb_table" "user_inventory" {
  name         = "${var.project_name}-user-inventory-${local.environment}"
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

# DynamoDB garden_tasks 

resource "aws_dynamodb_table" "garden_tasks" {
  name         = "${var.project_name}-garden-tasks-${local.environment}"
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

# DynamoDB table user data 
resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-users-${local.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
  tags = local.common_tags

}



resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role-${local.environment}"

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
  name   = "${var.project_name}-lambda-ssm-policy-role-${local.environment}"
  role   = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/plant-app/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "${var.project_name}-lambda-dynamodb-policy-role-${local.environment}"
  role   = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
        Resource = [
          aws_dynamodb_table.plants.arn,
          "${aws_dynamodb_table.plants.arn}/index/*",
          aws_dynamodb_table.garden_tasks.arn,
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.user_inventory.arn
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy" "lambda_sns" {
  name = "${var.project_name}-lambda-sns-policy-${local.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.garden_notifications.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ses" {
  name = "${var.project_name}-lambda-ses-policy-${local.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ses:SendEmail"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_sfn" {
  name = "${var.project_name}-lambda-sfn-policy-${local.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.add_to_inventory.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_translate" {
  name = "${var.project_name}-lambda-translate-policy-${local.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "translate:TranslateText"
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "translate_plant_name" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/translate_plant_name"
  output_path = "${path.module}/translate_plant_name.zip"
}

resource "aws_lambda_function" "translate_plant_name" {
  filename         = data.archive_file.translate_plant_name.output_path
  function_name    = "${var.project_name}-translate-plant-name-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.translate_plant_name.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      ANTHROPIC_API_KEY_PATH = "/plant-app/dev/anthropic-api-key"
    }
  }   
  tags = local.common_tags
}


resource "aws_api_gateway_rest_api" "plant_api" {
  name        = "${var.project_name}-plant-api-${local.environment}"
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

resource "aws_api_gateway_integration" "translate_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.translate.id
  http_method             = aws_api_gateway_method.translate_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.translate_plant_name.invoke_arn
}

resource "aws_api_gateway_resource" "get_tasks" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  parent_id   = aws_api_gateway_rest_api.plant_api.root_resource_id
  path_part   = "tasks"
}

resource "aws_api_gateway_resource" "inventory" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  parent_id   = aws_api_gateway_rest_api.plant_api.root_resource_id
  path_part   = "inventory"
}


resource "aws_api_gateway_method" "get_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.get_tasks.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "patch_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.get_tasks.id
  http_method   = "PATCH"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_inventory" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.inventory.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "start_inventory_flow" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.inventory.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_tasks_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.get_tasks.id
  http_method             = aws_api_gateway_method.get_tasks.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_tasks.invoke_arn
}

resource "aws_api_gateway_integration" "patch_tasks_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.get_tasks.id
  http_method             = aws_api_gateway_method.patch_tasks.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_task.invoke_arn
}

resource "aws_api_gateway_integration" "get_inventory_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.inventory.id
  http_method             = aws_api_gateway_method.get_inventory.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_inventory.invoke_arn
}

resource "aws_api_gateway_integration" "start_inventory_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.inventory.id
  http_method             = aws_api_gateway_method.start_inventory_flow.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.start_inventory_flow.invoke_arn
}


resource "aws_api_gateway_deployment" "plant_api" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id

  triggers = {
  redeployment = sha1(jsonencode([
    aws_api_gateway_integration.translate_integration,
    aws_api_gateway_integration.generate_plan_integration,
    aws_api_gateway_integration.users_integration,
    aws_api_gateway_integration.get_tasks_integration,
    aws_api_gateway_integration.get_inventory_integration,
    aws_api_gateway_integration.start_inventory_integration,
    aws_api_gateway_integration.patch_tasks_integration,
    aws_api_gateway_integration.tasks_options_integration,
    aws_api_gateway_integration.inventory_options_integration,
    aws_api_gateway_integration.users_options_integration,
    aws_api_gateway_integration.translate_options_integration,
    aws_api_gateway_integration.plants_options_integration,
    aws_api_gateway_integration.generate_plan_options_integration,
    aws_api_gateway_integration.suggest_integration,
    aws_api_gateway_integration.suggest_options_integration,
    aws_api_gateway_integration.inventory_delete_integration,
  ]))
}

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
  aws_api_gateway_integration.translate_integration,
  aws_api_gateway_integration.generate_plan_integration,
  aws_api_gateway_integration.users_integration,
  aws_api_gateway_integration.get_tasks_integration,
  aws_api_gateway_integration.get_inventory_integration,
  aws_api_gateway_integration.start_inventory_integration,
  aws_api_gateway_integration.inventory_delete_integration
  ]
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.plant_api.id
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  stage_name    = local.environment
}

resource "aws_lambda_permission" "translate_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translate_plant_name.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_tasks" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_tasks.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "update_tasks" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_inventory" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_inventory.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "start_inventory_flow" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_inventory_flow.function_name
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
  function_name    = "${var.project_name}-generate-garden-plan-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.generate_garden_plan.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_GARDEN_TASKS = aws_dynamodb_table.garden_tasks.name,
      DYNAMODB_TABLE_USERS = aws_dynamodb_table.users.name,
      DYNAMODB_TABLE_USER_INVENTORY = aws_dynamodb_table.user_inventory.name,
      ANTHROPIC_API_KEY_PATH = "/plant-app/dev/anthropic-api-key"
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

data "archive_file" "verify_update_tasks" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/verify_update_tasks"
  output_path = "${path.module}/verify_update_tasks.zip"
}

resource "aws_lambda_function" "verify_update_tasks" {
  filename         = data.archive_file.verify_update_tasks.output_path
  function_name    = "${var.project_name}-verify-update-tasks-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.verify_update_tasks.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_GARDEN_TASKS = aws_dynamodb_table.garden_tasks.name
      SNS_TOPIC_ARN               = aws_sns_topic.garden_notifications.arn
      DYNAMODB_TABLE_USERS = aws_dynamodb_table.users.name
      SES_SENDER_EMAIL = "brzojr@gmail.com"
      ANTHROPIC_API_KEY_PATH = "/plant-app/dev/anthropic-api-key"
      OPENWEATHER_API_KEY_PATH = "/plant-app/dev/openweather-api-key"
    }
}

  tags = local.common_tags
}


resource "aws_scheduler_schedule" "verify_update_tasks" {
  name       = "verify_tasks"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 8 15 * ? *)"

  target {
    arn      = aws_lambda_function.verify_update_tasks.arn
    role_arn = aws_iam_role.scheduler_role.arn
  }


}
# Lambda permission to allow EventBridge Scheduler to invoke the function
resource "aws_lambda_permission" "verify_update_tasks" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.verify_update_tasks.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.verify_update_tasks.arn
}

resource "aws_iam_role" "scheduler_role" {
  name = "${var.project_name}-scheduler-role-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "scheduler_lambda_policy" {
  name = "${var.project_name}-scheduler-lambda-policy-${local.environment}"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.verify_update_tasks.arn
      }
    ]
  })
}


resource "aws_sns_topic" "garden_notifications" {
  name = "${var.project_name}-notifications-${local.environment}"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.garden_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

data "archive_file" "add_user" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/add_user"
  output_path = "${path.module}/add_user.zip"
}

resource "aws_lambda_function" "add_user" {
  filename         = data.archive_file.add_user.output_path
  function_name    = "${var.project_name}-add-user-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.add_user.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_USERS = aws_dynamodb_table.users.name
    }
  }

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  parent_id   = aws_api_gateway_rest_api.plant_api.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_method" "users_post" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = aws_api_gateway_method.users_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.add_user.invoke_arn
}

resource "aws_lambda_permission" "add_user_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_user.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}


resource "aws_sfn_state_machine" "add_to_inventory" {
  name     = "${var.project_name}-state-machine-${local.environment}"
  role_arn = aws_iam_role.sfn_role.arn
  definition = jsonencode({
    "Comment": "Add plant to inventory flow",
    "StartAt": "SaveAndPlan",
    "States" : {
      "SaveAndPlan": {
        "Type": "Parallel",
        "Branches": [
          {"StartAt": "AddToInventory",
           "States": {
             "AddToInventory": {
               "Type": "Task",
               "Resource": "${aws_lambda_function.add_to_inventory.arn}",
               "End": true
              }
            }
          },
          { "StartAt": "GenerateGardenPlan",
            "States": {
            "GenerateGardenPlan": {
              "Type": "Task",
              "Resource": "${aws_lambda_function.generate_garden_plan.arn}",
              "End": true
              }
            }
          }
        ],
        "End": true
      }
    }
  })
}

# IAM Role for Step Functions
resource "aws_iam_role" "sfn_role" {
  name = "${var.project_name}-sfn-role-${local.environment}"
  # Trust policy: allows Step Functions to assume this role
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

# IAM Policy for Step Functions to invoke Lambda
resource "aws_iam_policy" "sfn_role_policy" {
  name        = "${var.project_name}-sfn-role-policy-${local.environment}"
  description = "Allows Step Functions to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "${aws_lambda_function.translate_plant_name.arn}",
          "${aws_lambda_function.add_to_inventory.arn}",
          "${aws_lambda_function.generate_garden_plan.arn}"
        ]
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach_sfn_policy" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_role_policy.arn
}


data "archive_file" "get_tasks" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/get_tasks"
  output_path = "${path.module}/get_tasks.zip"
}

resource "aws_lambda_function" "get_tasks" {
  filename         = data.archive_file.get_tasks.output_path
  function_name    = "${var.project_name}-get-tasks-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.get_tasks.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_GARDEN_TASKS = aws_dynamodb_table.garden_tasks.name
    }
  }

  tags = local.common_tags
}

data "archive_file" "get_inventory" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/get_inventory"
  output_path = "${path.module}/get_inventory.zip"
}

resource "aws_lambda_function" "get_inventory" {
  filename         = data.archive_file.get_inventory.output_path
  function_name    = "${var.project_name}-get-inventory-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.get_inventory.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_USER_INVENTORY = aws_dynamodb_table.user_inventory.name
    }
  }

  tags = local.common_tags
}

data "archive_file" "add_to_inventory" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/add_to_inventory"
  output_path = "${path.module}/add_to_inventory.zip"
}

resource "aws_lambda_function" "add_to_inventory" {
  filename         = data.archive_file.add_to_inventory.output_path
  function_name    = "${var.project_name}-add-to-inventory-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.add_to_inventory.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_USER_INVENTORY = aws_dynamodb_table.user_inventory.name
    }
  }

  tags = local.common_tags
}

data "archive_file" "start_inventory_flow" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/start_inventory_flow"
  output_path = "${path.module}/start_inventory_flow.zip"
}

resource "aws_lambda_function" "start_inventory_flow" {
  filename         = data.archive_file.start_inventory_flow.output_path
  function_name    = "${var.project_name}-start-inventory-flow-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.start_inventory_flow.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.add_to_inventory.arn
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "translate_sfn" {
  statement_id  = "AllowStepFunctionsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translate_plant_name.function_name
  principal     = "states.amazonaws.com"
  source_arn    = aws_sfn_state_machine.add_to_inventory.arn
}

resource "aws_lambda_permission" "add_to_inventory_sfn" {
  statement_id  = "AllowStepFunctionsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_to_inventory.function_name
  principal     = "states.amazonaws.com"
  source_arn    = aws_sfn_state_machine.add_to_inventory.arn
}

resource "aws_lambda_permission" "generate_garden_plan_sfn" {
  statement_id  = "AllowStepFunctionsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_garden_plan.function_name
  principal     = "states.amazonaws.com"
  source_arn    = aws_sfn_state_machine.add_to_inventory.arn
}

data "archive_file" "update_task" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/update_task"
  output_path = "${path.module}/update_task.zip"
}

resource "aws_lambda_function" "update_task" {
  filename         = data.archive_file.update_task.output_path
  function_name    = "${var.project_name}-update-task-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.update_task.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_GARDEN_TASKS = aws_dynamodb_table.garden_tasks.name
    }
  }

  tags = local.common_tags
}

data "archive_file" "suggest_plants" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/suggest_plants"
  output_path = "${path.module}/suggest_plants.zip"
}

resource "aws_lambda_function" "suggest_plants" {
  filename         = data.archive_file.suggest_plants.output_path
  function_name    = "${var.project_name}-suggest-plants-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.suggest_plants.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_PLANTS = aws_dynamodb_table.plants.name
    }
  }

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "suggest" {
  rest_api_id = aws_api_gateway_rest_api.plant_api.id
  parent_id   = aws_api_gateway_rest_api.plant_api.root_resource_id
  path_part   = "suggest"
}

resource "aws_api_gateway_method" "suggest_post" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.suggest.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "suggest_integration" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.suggest.id
  http_method             = aws_api_gateway_method.suggest_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.suggest_plants.invoke_arn
}

resource "aws_lambda_permission" "suggest_plant_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.suggest_plants.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}


data "archive_file" "delete_from_inventory" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/delete_from_inventory"
  output_path = "${path.module}/delete_from_inventory.zip"
}

resource "aws_lambda_function" "delete_from_inventory" {
  filename         = data.archive_file.delete_from_inventory.output_path
  function_name    = "${var.project_name}-delete-from-inventory-${local.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.delete_from_inventory.output_base64sha256
  timeout          = 50  
  environment {
    variables = {
      DYNAMODB_TABLE_GARDEN_TASKS = aws_dynamodb_table.garden_tasks.name
      DYNAMODB_TABLE_USER_INVENTORY = aws_dynamodb_table.user_inventory.name
    }
  }

  tags = local.common_tags
}

resource "aws_api_gateway_method" "inventory_delete" {
  rest_api_id   = aws_api_gateway_rest_api.plant_api.id
  resource_id   = aws_api_gateway_resource.inventory.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "inventory_delete" {
  rest_api_id             = aws_api_gateway_rest_api.plant_api.id
  resource_id             = aws_api_gateway_resource.inventory.id
  http_method             = aws_api_gateway_method.inventory_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.delete_from_inventory.invoke_arn
}

resource "aws_lambda_permission" "delete_from_inventory" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_from_inventory.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.plant_api.execution_arn}/*/*"
}

resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "${var.project_name}-frontend-${local.environment}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  depends_on = [aws_cloudfront_distribution.frontend]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend_bucket.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}

resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project_name}-oac-${local.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
    origin_id                = aws_s3_bucket.frontend_bucket.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Plant App CloudFront distribution"
  default_root_object = "login.html"

 

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.frontend_bucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = local.common_tags

  viewer_certificate {
   cloudfront_default_certificate = true
}
}

