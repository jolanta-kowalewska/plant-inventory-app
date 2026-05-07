import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USER_INVENTORY'])

def lambda_handler(event, context):
    print(f"Event received: {event}")
        
    user_id = event['user_id']
    plant_name = event['plant_name']
    plant_name_pl = event.get('plant_name_pl', plant_name)  # polska — dla UI
    species_id = event['species_id']
    scientific_name = event.get('scientific_name', '') 
    message = save_item_to_inventory(user_id, plant_name, plant_name_pl, species_id, scientific_name)

    return {'status': 'success', 'plant_name': plant_name, 'species_id': species_id}

def save_item_to_inventory(user_id, plant_name, plant_name_pl, species_id, scientific_name):

    table.put_item(Item={
        'user_id': str(user_id),
        'plant_name': str(plant_name),
        'plant_name_pl': str(plant_name_pl),
        'species_id':str(species_id),
        'scientific_name': str(scientific_name)
    })

    return f"Item: {plant_name} with id: {species_id} saved to {user_id} inventory in DynamoDB table"

        