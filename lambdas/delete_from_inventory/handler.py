import json
import os
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')

garden_table = dynamodb.Table(os.environ['DYNAMODB_TABLE_GARDEN_TASKS'])
user_table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USER_INVENTORY'])


def lambda_handler(event, context):
    print(f"Event received: {event}")
 

    if 'body' in event:
        body = json.loads(event['body'])  # API Gateway
    else:
        body = event  # Step Functions

    user_id = body['user_id']           # user_id we get from json dict (event) comming to lambda
    plant_name = body['plant_name']     #plant_name of a plant to remove - filtering task
    species_id = body['species_id']     # to remove from user_inventory

    remove_from_user = delete_from_user_inventory(user_id, species_id)
    tasks_to_delete = get_plant_tasks(user_id, plant_name)
    delete_tasks = delete_plant_tasks(user_id, tasks_to_delete)
    
    return {
    'statusCode': 200,
    'headers': {'Access-Control-Allow-Origin': '*'},
    'body': json.dumps({
        'message': f'Removed {plant_name} and {len(tasks_to_delete)} tasks'
    })
}

def delete_from_user_inventory(user_id, species_id):

    response = user_table.delete_item(
        Key={"user_id": user_id, "species_id": species_id}
    )
    
    return response

def get_plant_tasks(user_id, plant_name):
    
    tasks_to_delete = []
    response = garden_table.query(
        KeyConditionExpression="#kn0 = :kv0 AND begins_with(#kn1, :kv1)",
            ExpressionAttributeNames={"#kn0": "user_id", "#kn1": "task_id"},
            ExpressionAttributeValues={":kv0": user_id, ":kv1": f"{user_id}-{plant_name}"}
        )


    for task in response['Items']:
        tasks_to_delete.append(task['task_id'])

    return tasks_to_delete

def delete_plant_tasks(user_id, tasks_to_delete): 
    
    with garden_table.batch_writer() as writer:
        for task in tasks_to_delete:
            writer.delete_item(
                Key={
                    'user_id' : user_id,
                    'task_id' : task
                })