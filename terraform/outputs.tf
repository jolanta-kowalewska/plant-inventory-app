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

output "fetch_plant_data_function_name" {
  value = aws_lambda_function.fetch_plant_data.function_name
}

output "fetch_plant_data_arn" {
  value = aws_lambda_function.fetch_plant_data.arn
}


output "translate_plant_name_function_name" {
  value = aws_lambda_function.translate_plant_name.function_name
}

output "translate_plant_name_arn" {
  value = aws_lambda_function.translate_plant_name.arn
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