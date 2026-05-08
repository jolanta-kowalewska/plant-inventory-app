import json
import os
import boto3

client = boto3.client('stepfunctions')

def lambda_handler(event, context):
    print(f"Event received: {event}")


    # both cases
    if 'body' in event:
        body = json.loads(event['body'])  # API Gateway
    else:
        body = event  # Step Functions
        
    user_id = body.get('user_id')
    plant_name = body.get('plant_name')
    plant_name_pl = body.get('plant_name_pl')
    species_id = body.get('species_id', '')
    scientific_name = body.get('scientific_name', '')
    
    if not user_id or not plant_name:
        return {
            'statusCode': 400, 
            'body': json.dumps({'error': 'user_id and plant_name are required'})
            }
    response = client.start_execution(
        stateMachineArn=os.environ['STATE_MACHINE_ARN'],
        input=json.dumps({
            "user_id": user_id,
            "plant_name": plant_name,
            "plant_name_pl": body.get('plant_name_pl', plant_name),
            "species_id": species_id,
            "scientific_name": scientific_name,
            "preferred_place": body.get('preferred_place', ''),
            "watering": body.get('watering', '')
        })
    )

    return {
    'statusCode': 202, 
    'headers': {'Access-Control-Allow-Origin': '*'},
    'body': json.dumps({
        'message': 'Plant is being added to inventory',
        'executionArn': response['executionArn']
    })
    }


