import requests
import boto3
import json
import os

def lambda_handler(event, context):

    try: 
        ssm = boto3.client('ssm', region_name=os.environ['AWS_REGION'])
        
        body = json.loads(event['body'])
        plant_name = body['plant_name'] # plant name we get from json dict (event) comming to lambda
        
        #aws ssm get parameter to get api_key for perenual 
        response = ssm.get_parameter(
            Name='/plant-app/dev/perenual-api-key',
            WithDecryption=True
        )

        api_key = response['Parameter']['Value']
        
        output = get_plant_data(api_key, plant_name)
        
        save_to_dynamodb(output)
        
        return {
            'statusCode': 200,
            'body': f"Saved {len(output['data'])} plants to DynamoDB"
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }
    
def get_plant_data(api_key, plant_name):

    url = f"https://perenual.com/api/species-list?key={api_key}&q={plant_name}"
    
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        return data
    except requests.exceptions.RequestException as e:
        raise Exception(f"Perenual API error: {str(e)}")


def save_to_dynamodb(data):

    dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE_PLANTS'])


    for plant in data['data']:
        # save every plant

        table.put_item(Item={
            'species_id': str(plant['id']),
            'common_name': plant['common_name'],
            'scientific_name' : plant['scientific_name'][0],
            'cycle' : plant.get('cycle'),  # return None if value is empty/null
            'watering' : plant.get('watering'),
            'sunlight' : plant.get('sunlight')
        })



