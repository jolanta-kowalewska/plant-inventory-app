# ============================================================
# SCRIPT: Lambda function AddToInventory
# AUTHOR: Jola
# DATE:   2026-05-13
#
# DESCRIPTION:
#   Adds plant and its attributes to the user inventory DynamoDB table *user-inventory
#
# ASSUMPTIONS:
#   - event comming to lambda with required input
#
# INPUTS:  {
#  "user_id": "***",
#  "plant_name": "magnolia cavaleriei",
#  "plant_name_pl": "magnolia cavaleriei",
#  "species_id": "Q15487666",
#  "scientific_name": "Magnolia cavaleriei",
#  "preferred_place": "",
#  "watering": ""
# }
#
# OUTPUTS: {
#  "status": "success",
#  "plant_name": "magnolia cavaleriei",
#  "species_id": "Q15487666"
# }
# ============================================================

import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USER_INVENTORY'])

def lambda_handler(event, context):
    print(f"Event received: {event}")
        
    item = {
    'user_id': str(event['user_id']),
    'plant_name': str(event['plant_name']),
    'plant_name_pl': str(event.get('plant_name_pl', event['plant_name'])),
    'species_id': str(event['species_id']),
    'scientific_name': str(event.get('scientific_name', '')),
    'preferred_place': str(event.get('preferred_place', '')),
    'watering': str(event.get('watering', '')),
    'image_url': str(event.get('image_url', ''))
    }
    result = save_item_to_inventory(item)

    print(result)

def save_item_to_inventory(item):

    table.put_item(Item=item)
    return f"Item: {item['plant_name']} saved"

        