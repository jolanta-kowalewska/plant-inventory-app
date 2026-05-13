# ============================================================
# SCRIPT: Lambda function SuggestPlants
# AUTHOR: Jola
# DATE:   2026-05-13
#
# DESCRIPTION:
#   Lambda function executed when user enters a plant name and the lambda is suggesting all plant names species
#
# ASSUMPTIONS:
#   Genus name for entered plant  
#
# INPUTS: 'body': '{"genus_name": "magnolia"}'
#
# OUTPUTS: {'body': '[{suggested_plant1},{suggested_plant2},...]}
# 
# ============================================================

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
    try: 

        body = json.loads(event.get('body', '{}'))
        genus_name = body.get('genus_name', '').strip().lower()

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
    
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
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
            'plant_name_pl': item.get('plant_name_pl', item.get('plant_name', '')),
            'scientific_name': item.get('scientific_name', ''),
            'preferred_place': item.get('preferred_place', ''),
            'watering': item.get('watering', '')
        })

    suggested_plants.sort(key=lambda p: p['plant_name_pl'])
    return suggested_plants