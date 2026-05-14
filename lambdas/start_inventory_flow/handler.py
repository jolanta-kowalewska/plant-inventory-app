# ============================================================
# SCRIPT: Lambda function StartInventoryFlow
# AUTHOR: Jola
# DATE:   2026-05-13
#
# DESCRIPTION:
#   Start function lambda for Step Functions orchiestration  
#
# ASSUMPTIONS:
#   User Id is required to display tasks  
#
# INPUTS: {
#  "user_id": "brzojr@gmail.com",
#  "plant_name": "magnolia cavaleriei",
#  "plant_name_pl": "magnolia cavaleriei",
#  "species_id": "Q15487666",
#  "scientific_name": "Magnolia cavaleriei",
# }
#
# OUTPUTS: {
#  "user_id": "brzojr@gmail.com",
#  "plant_name": "magnolia cavaleriei",
#  "plant_name_pl": "magnolia cavaleriei",
#  "species_id": "Q15487666",
#  "scientific_name": "Magnolia cavaleriei",
#  "preferred_place": "",
#  "watering": ""
# }
# ============================================================

import json
import os
import boto3

client = boto3.client('stepfunctions')

def lambda_handler(event, context):
    print(f"Event received: {event}")


    body = json.loads(event['body'])  # API Gateway
        
    sf_input = {
        "user_id": body['user_id'],
        "plant_name": body['plant_name'],
        "plant_name_pl": body.get('plant_name_pl', body['plant_name']),
        "species_id": body.get('species_id', ''),
        "scientific_name": body.get('scientific_name', ''),
        "preferred_place": body.get('preferred_place', ''),
        "watering": body.get('watering', ''),
        "image_url":body.get('image_url','')
    }
    
    if not sf_input['user_id'] or not sf_input['plant_name']:
        return {
            'statusCode': 400, 
            'headers': {'Access-Control-Allow-Origin': '*'},  
            'body': json.dumps({'error': 'user_id and plant_name are required'})
            }
    response = client.start_execution(
        stateMachineArn=os.environ['STATE_MACHINE_ARN'],
        input=json.dumps(sf_input)
    )

    return {
    'statusCode': 202, 
    'headers': {'Access-Control-Allow-Origin': '*'},
    'body': json.dumps({
        'message': 'Plant is being added to inventory',
        'executionArn': response['executionArn']
    })
    }


