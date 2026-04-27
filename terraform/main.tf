terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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

