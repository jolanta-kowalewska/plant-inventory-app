# ============================================================
# SCRIPT: Lambda function GetTasks
# AUTHOR: Jola
# DATE:   2026-05-13
#
# DESCRIPTION:
#   Displays care plant tasks for website 
#
# ASSUMPTIONS:
#   User Id is required to display tasks  
#
# INPUTS:  
#     {'user_id': 'test@example.com'}
#
# OUTPUTS: {
#     "statusCode": 200,
#     "headers": {...},
#     "body": "[{task1}, {task2}, ...]"
#   }
# ============================================================

import json
import os
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_GARDEN_TASKS'])


def get_tasks_for_user(user_id: str) -> list:
    response = table.query(
        KeyConditionExpression=Key('user_id').eq(user_id)
    )
    return response['Items']


def lambda_handler(event, context):
    print(f"Event received: {event}")
    user_id = event.get('queryStringParameters', {}).get('user_id')
    
    if not user_id:
        return {
            'statusCode': 400,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'user_id is required'})
        }
    
    tasks = get_tasks_for_user(user_id)
    
    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(tasks)
    }