# ============================================================
# SCRIPT: Lambda function AddUser 
# AUTHOR: Jola
# DATE:   2026-05-13
#
# DESCRIPTION:
#   Add user to the DynamoDB table *table
#
# ASSUMPTIONS:
#   User adds location details for weather forcast data required to suggest changes in care plan.
#
# INPUTS:  
#     {'user_id': 'test@example.com', 'name': 'Test User', 'location': 'Warsaw', 'language': 'Polish'}
#
# OUTPUTS: User {name} with id: {user_id} saved to DynamoDB table"
# ============================================================

import boto3
import json
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USERS'])

def lambda_handler(event, context):
    
    print(f"Event received: {event}")
    
    try:    
        body = json.loads(event['body'])
        item = {
            'user_id': str(body['user_id']),
            'name': str(body['name']),
            'location': str(body['location']),
            'language': str(body['language']),
        }
        result = save_user_to_dynamodb(item)

        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'message': result})
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': f"Error: {str(e)}"
        }


def save_user_to_dynamodb(item):

    table.put_item(Item=item)
    return f"User saved"

        
        