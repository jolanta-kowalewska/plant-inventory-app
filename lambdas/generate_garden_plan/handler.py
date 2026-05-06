import boto3
import json
import os
import anthropic
from datetime import datetime

ssm = boto3.client('ssm')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_GARDEN_TASKS'])
users_table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USERS'])

def lambda_handler(event, context):
    print(f"Event received: {event}")
 
    # both cases for API gateway and Step Functions event
    if 'body' in event:
        body = json.loads(event['body'])  # API Gateway
    else:
        body = event  # Step Functions
            
    user_id = body['user_id'] # user_id we get from json dict (event) comming to lambda
    plant_name = body['plant_data']['plant_name']

    #aws ssm get parameter to get api_key for claude 
    response = ssm.get_parameter(
        Name=os.environ['ANTHROPIC_API_KEY_PATH'],
        WithDecryption=True
    )
    api_key = response['Parameter']['Value']
        
    #get location and language from Users table
    user_profile = get_user_profile(user_id)
    user_location = user_profile['location']
    user_language = user_profile.get('language', 'English')

    # function to create care job for plants in set with localization
    care_jobs = plant_care_job(api_key, plant_name, user_location, user_language)

    # create tasks list from the output & put tasks into DynamoDB table 
    output = save_tasks_to_dynamodb(user_id, plant_name, care_jobs)
                
    return {'status': 'success', 'tasks_saved': output}
    
def plant_care_job(api_key, plant_name, user_location, user_language):

    current_year = datetime.now().year

    prompt = f"""You are an expert gardener creating a plant care schedule.
        Create a full year care plan ONLY for the plant: {plant_name}.
        All tasks must be related to plant care (watering, pruning, fertilizing, pest control etc.)
        Do NOT include any non-plant-related tasks.
        Location: {user_location}
        If a task is recurring (e.g. every 2 weeks), create a separate task entry for each occurrence
        Create tasks for the year {current_year}.
        IMPORTANT: All task descriptions must be written in {user_language}.
        Return ONLY a JSON object: {{"tasks": [{{"task_number": 1, "description": "task", "date": "YYYY-MM-DD"}}]}}"""
    


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

def save_tasks_to_dynamodb(user_id, plant_name, task_list):

    # remove markdown if added by Claude
    task_list_clean = task_list.strip()
    if task_list_clean.startswith("```"):
        task_list_clean = task_list_clean.split("```")[1]
        if task_list_clean.startswith("json"):
            task_list_clean = task_list_clean[4:]

    parsed = json.loads(task_list_clean.strip())
    tasks = parsed['tasks']           

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
            'plant_name': str(plant_name),
            'status' : "pending"
        })

    return len(tasks)


def get_user_profile(user_id):

    response = users_table.get_item(
        Key = {'user_id': user_id}
    )

    return response['Item']