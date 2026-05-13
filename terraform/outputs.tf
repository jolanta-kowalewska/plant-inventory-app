output "plants_arn" {
  value = aws_dynamodb_table.plants.arn
}

output "plants_name" {
  value = aws_dynamodb_table.plants.name
}


output "user_inventory_arn" {
  value = aws_dynamodb_table.user_inventory.arn
}

output "user_inventory_name" {
  value = aws_dynamodb_table.user_inventory.name
}

output "garden_tasks_arn" {
  value = aws_dynamodb_table.garden_tasks.arn
}

output "garden_tasks_name" {
  value = aws_dynamodb_table.garden_tasks.name
}

output "api_gateway_url" {
  value = "${aws_api_gateway_stage.dev.invoke_url}"
}

output "generate_garden_plan_function_name" {
  value = aws_lambda_function.generate_garden_plan.function_name
}

output "generate_garden_plan_arn" {
  value = aws_lambda_function.generate_garden_plan.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.garden_notifications.arn
}

output "users_table_name" {
  value = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  value = aws_dynamodb_table.users.arn
}

output "add_user_function_name" {
  value = aws_lambda_function.add_user.function_name
}

output "add_user_arn" {
  value = aws_lambda_function.add_user.arn
}

output "get_tasks_function_name" {
  value = aws_lambda_function.get_tasks.function_name
}

output "get_inventory_function_name" {
  value = aws_lambda_function.get_inventory.function_name
}

output "add_to_inventory_function_name" {
  value = aws_lambda_function.add_to_inventory.function_name
}

output "start_inventory_flow_function_name" {
  value = aws_lambda_function.start_inventory_flow.function_name
}

output "update_task_function_name" {
  value = aws_lambda_function.update_task.function_name
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.add_to_inventory.arn
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend_bucket.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "suggest_plants_function_name" {
  value = aws_lambda_function.suggest_plants.function_name
}