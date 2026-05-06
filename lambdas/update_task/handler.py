import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_GARDEN_TASKS'])

def update_task(task_id, user_id, status):

    response = table.update_item(
        Key={
        'user_id': user_id,
        'task_id': task_id
        },
    UpdateExpression="SET #s = :val",
    ExpressionAttributeNames={'#s': 'status'},
    ExpressionAttributeValues={':val': status
    },
    ReturnValues="ALL_NEW"
    )
    print(response['Attributes'])

    return f"Task with id: {task_id} updated with status {status}"


def lambda_handler(event, context):
    
    print(f"Event received: {event}")
    
    body = json.loads(event['body'])
    task_id = body['task_id']
    user_id = body['user_id']
    status = body['status']

    if not all([task_id, user_id, status]):
        return {
            'statusCode': 400,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'At least one of a value is empty'})
        }

    message = update_task(task_id, user_id, status)

    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({'message' : message})
    }