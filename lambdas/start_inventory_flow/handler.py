import json
import os
import boto3

client = boto3.client('stepfunctions')

def lambda_handler(event, context):
    print(f"Event received: {event}")

    body = json.loads(event['body'])
    user_id = body.get('user_id')
    plant_name = body.get('plant_name')
    
    if not user_id or not plant_name:
        return {
            'statusCode': 400, 
            'body': json.dumps({'error': 'user_id and plant_name are required'})
            }
    response = client.start_execution(
        stateMachineArn=os.environ['STATE_MACHINE_ARN'],
        input=json.dumps({"user_id": user_id, "plant_name": plant_name})
    )

    return {
    'statusCode': 202, 
    'headers': {'Access-Control-Allow-Origin': '*'},
    'body': json.dumps({
        'message': 'Plant is being added to inventory',
        'executionArn': response['executionArn']
    })
    }


