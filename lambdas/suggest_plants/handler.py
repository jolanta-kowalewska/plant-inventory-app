import json
import os
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_PLANTS'])

#user enters a plant_name i.e "magnolia" and this lambda is suggesting which plant_name in details (magnolia stellata i.e )
def lambda_handler(event, context):
    print(f"Event received: {event}")

    # this is a case for API gateway (Step Functions comes in later)
    body = json.loads(event['body'])  # API Gateway   
    
    genus_name = body['genus_name']

    if not genus_name:
        return {
            'statusCode': 400, 
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'plant_name is required'})
            }
    output = query_plant(genus_name)

    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(output)
    }


def query_plant(genus_name):

    response = table.query(
        IndexName='genus_name-index',
        KeyConditionExpression=Key('genus_name').eq(genus_name)
    )

    suggested_plants = []
    for item in response['Items']:
        suggested_plants.append({
            'species_id': item['species_id'],
            'plant_name': item['plant_name'],
            'scientific_name': item.get('scientific_name', ''),
            'preferred_place': item.get('preferred_place', ''),
            'watering': item.get('watering', '')
        })

    return suggested_plants