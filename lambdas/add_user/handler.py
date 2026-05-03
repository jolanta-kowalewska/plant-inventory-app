import boto3
import json
import os


def lambda_handler(event, context):

    try:    
        body = json.loads(event['body'])
        user_id = body['user_id'] # user_id we get from json dict (event) comming to lambda
        name = body['name']
        location = body['location']

        message = save_user_to_dynamodb(user_id, name, location)

        return {
            'statusCode': 200,
            'body': message
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }


def save_user_to_dynamodb(user_id, name, location):

    dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])
    
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USERS'])

    table.put_item(Item={
        'user_id': str(user_id),
        'name': str(name),
        'location': str(location),
        'status' : "pending"
    })

    return f"User {name} with id: {user_id} saved to DynamoDB table"

        
        