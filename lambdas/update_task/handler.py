# ============================================================
# SCRIPT: Lambda function UpdateTasks
# AUTHOR: Jola
# DATE:   2026-05-13
#
# DESCRIPTION:
#   Lambda function executed when user check the task as completed
#
# ASSUMPTIONS:
#   user_id and task_id required to change the status of the task  
#
# INPUTS:  
#    'body': {'user_id': 'test@example.com', 'task_id': 'user_id-plant_number'}
#
#
# OUTPUTS: Task with id: {task_id} updated with status {status}
# 
# ============================================================
import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_GARDEN_TASKS'])

def update_task(task_id, user_id, status):

    response = table.update_item(
        Key={'user_id': user_id, 'task_id': task_id},
        UpdateExpression="SET #s = :val",
        ConditionExpression="attribute_exists(task_id)",
        ExpressionAttributeNames={'#s': 'status'},
        ExpressionAttributeValues={':val': status},
        ReturnValues="ALL_NEW"
    )
    
    return f"Task with id: {task_id} updated with status {status}"


def lambda_handler(event, context):
    
    print(f"Event received: {event}")
    
    body = json.loads(event['body'])
    task_id = body.get('task_id')
    user_id = body.get('user_id')
    status = body.get('status')

    if not all([task_id, user_id, status]):
        return {
            'statusCode': 400,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'At least one of a value is empty'})
        }

    if status not in ('done', 'pending'):
        return {
            'statusCode': 400,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'status must be done or pending'})
        }

    message = update_task(task_id, user_id, status)

    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({'message' : message})
    }