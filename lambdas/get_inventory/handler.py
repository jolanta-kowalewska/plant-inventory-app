# ============================================================
# SCRIPT: Lambda function GetInventory
# AUTHOR: Jola
# DATE:   2026-05-13
#
# DESCRIPTION:
#   Displays Inventory of user plants for website page /inventory
#
# ASSUMPTIONS:
#   User Id is required to display invenotry  
#
# INPUTS:  
#     {'user_id': 'test@example.com'}
#
# OUTPUTS: #
# ============================================================

import json
import os
import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj) if obj % 1 else int(obj)
        return super().default(obj)

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USER_INVENTORY'])


def get_inventory_for_user(user_id: str) -> list:
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
    
    inventory = get_inventory_for_user(user_id)
    
    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(inventory, cls=DecimalEncoder)
    }