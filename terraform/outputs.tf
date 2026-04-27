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