import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USER_INVENTORY'])

def lambda_handler(event, context):
    print(f"Event received: {event}")
        
    user_id = event['user_id'] # user_id we get from event dict comming to lambda
    user_id = event['user_id']
    plant_name = event['plant_data']['plant_name']
    species_id = event['plant_data']['species_id']
        
    message = save_item_to_inventory(user_id, plant_name, species_id)

    return {'status': 'success', 'plant_name': plant_name, 'species_id': species_id}

def save_item_to_inventory(user_id, plant_name, species_id):

    table.put_item(Item={
        'user_id': str(user_id),
        'plant_name': str(plant_name),
        'species_id':str(species_id)
    })

    return f"Item: {plant_name} with id: {species_id} saved to {user_id} inventory in DynamoDB table"

        