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
  timeout          = 30  # 30 sekund — wystarczy dla zewnętrznych API
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