import requests
import boto3
import json
import os
import anthropic
from datetime import datetime

def lambda_handler(event, context):
    print(f"Event received: {event}")
    # event it will be: event = {"body": '{"user_id": "jolanta"}'}  -> comes from api gateway
    try: 
        ssm = boto3.client('ssm', region_name=os.environ['AWS_REGION'])
        
        body = json.loads(event['body'])
        user_id = body['user_id'] # user_id we get from json dict (event) comming to lambda
        
        #aws ssm get parameter to get api_key for perenual 
        response = ssm.get_parameter(
            Name='/plant-app/dev/anthropic-api-key',
            WithDecryption=True
        )

        api_key = response['Parameter']['Value']

        ### later add logic 
        # TODO: replace with plants from user_inventory
        # TODO: replace with location from user profile
             
        # function to create care job for plants in set with localization
        care_jobs = plant_care_job(api_key, plant_name = "dhalia", user_location = "Bydgoszcz, Poland")

        # create tasks list from the output & put tasks into DynamoDB table 

        output = save_tasks_to_dynamodb(user_id, plant_name = "dhalia", task_list = care_jobs)
                
        return {
            'statusCode': 200,
            'body': f"Saved {len(output)} plants to DynamoDB"  
        }
    except Exception as e:
        print(f"Error details: {str(e)}")
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }
    

def plant_care_job(api_key, plant_name, user_location):

    current_year = datetime.now().year

    prompt = f"""Please create the full year care plan for {plant_name}.
        The care plan must be max 1 sentence per task.
        Location: {user_location}
        If a task is recurring (e.g. every 2 weeks), create a separate task entry for each occurrence
        Create tasks for the year {current_year}.
        Return ONLY a JSON object: {{"tasks": [{{"task_number": 1, "description": "task", "date": "YYYY-MM-DD"}}]}}"""
    

    try:
        client = anthropic.Anthropic(api_key=api_key)

        message = client.messages.create(
        model="claude-haiku-4-5-20251001",  # the cheapest option, enough for translate job
        max_tokens=2000,                      
        messages=[
            {
                "role": "user",
                "content": prompt  # tu wpisujesz swój prompt
            }
        ]
        )

        task_list = message.content[0].text

        return task_list

    except Exception as e:
        raise Exception(f"Anthropic API error: {str(e)}")
    


def save_tasks_to_dynamodb(user_id, plant_name, task_list):

    parsed = json.loads(task_list)   # najpierw parsuj cały string
    tasks = parsed['tasks']           # potem pobierz listę tasków

    dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])
    
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE_GARDEN_TASKS'])

    for task in tasks:
        # save every task

        #generate task id 
        task_id = f"{user_id}-{plant_name}-{task['task_number']}"
        # np. "jolanta-dahlia-1"
        table.put_item(Item={
            'user_id': str(user_id),
            'task_id': str(task_id),
            'task_number': str(task['task_number']),
            'description' : str(task['description']),
            'date' : str(task['date']),
            'status' : "pending"
        })

    return len(tasks)