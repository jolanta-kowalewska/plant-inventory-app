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
        
        #aws ssm get parameter to get api_key for claude 
        response = ssm.get_parameters(
        Names=[
            '/plant-app/dev/anthropic-api-key',
            '/plant-app/dev/openweather-api-key'
        ],
        WithDecryption=True
        )

        params = {p['Name']: p['Value'] for p in response['Parameters']}
        anthropic_api_key = params['/plant-app/dev/anthropic-api-key']
        weather_api_key = params['/plant-app/dev/openweather-api-key']



        user_id = "jolanta" # def get_users_id() TODO
        location = "Bydgoszcz, Poland" #hardcoded TODO to get it from user profile

        month = (datetime.now().month % 12) + 1  # grudzień → 1 (styczeń)

        tasks = get_tasks(user_id, month)

        weather = get_weather(location, weather_api_key)

        verified_tasks = verify_tasks_with_claude(tasks, weather, anthropic_api_key, month)

        #TODO update tasks list 

        output = update_tasks_list(verified_tasks)

        return {
            'statusCode': 200,
            'body': f"Saved {output} tasks to DynamoDB"  
        }

    except Exception as e:
        print(f"Error details: {str(e)}")
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }
    

# TODO Pobierz wszystkich user_id z DynamoDB (scan tabeli users)
 
def get_users_id():
    pass

def get_tasks(user_id, month):
    from boto3.dynamodb.conditions import Key, Attr
    
    dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])   
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE_GARDEN_TASKS'])

    try:

        # pobierz taski dla konkretnego user_id
        response = table.query(
            KeyConditionExpression=Key('user_id').eq(user_id)
        )
        
        # filtruj tylko taski na następny miesiąc
        next_month = str(month).zfill(2)  # np. "05" dla maja
        tasks = [t for t in response['Items'] 
                if t['date'].startswith(f"2026-{next_month}")]
        
        return tasks
    
    except Exception as e:
        print(f"Error details: {str(e)}")
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }

def get_weather(location, weather_api_key):

    # krok 1: pobierz lat/lon
    geo_url = f"http://api.openweathermap.org/geo/1.0/direct?q={location}&limit=1&appid={weather_api_key}"
    
    try: 

        geo_response = requests.get(geo_url)
        geo_data = geo_response.json()
        lat = geo_data[0]['lat']
        lon = geo_data[0]['lon']
        
        # krok 2: pobierz prognozę 5 dni
        forecast_url = f"https://api.openweathermap.org/data/2.5/forecast?lat={lat}&lon={lon}&appid={weather_api_key}&units=metric&cnt=40"
        
        forecast_response = requests.get(forecast_url)
        data = forecast_response.json()
        
        return data
    
    except requests.exceptions.RequestException as e:
        raise Exception(f"Perenual API error: {str(e)}")



def verify_tasks_with_claude(tasks, weather, anthropic_api_key, next_month):

    current_year = datetime.now().year

    # wyciągnij tylko co ważne z weather
    weather_summary = f"Temperature: {weather['list'][0]['main']['temp']}°C, Description: {weather['list'][0]['weather'][0]['description']}"

    prompt = f"""You are an expert gardener creating a plant care schedule.
        You have previously created a full year care plan for a specific plant. 
        Here is a the task list for next month {next_month} with task numbers: {tasks}
        IMPORTANT: Keep the same task_number for existing tasks.
        You may modify description or date, but keep task_number unchanged.

        All tasks must be reviewed considering weather conditions specific for location {weather_summary}. 
        Do NOT include any non-plant-related tasks.
    
        If a task is recurring (e.g. every 2 weeks), create a separate task entry for each occurrence
        Current year {current_year}. 
        Return ONLY a JSON object: {{"tasks": [{{"task_number": 1, "description": "task", "date": "YYYY-MM-DD"}}]}}"""
    

    try:
        client = anthropic.Anthropic(api_key=anthropic_api_key)

        message = client.messages.create(
        model="claude-haiku-4-5-20251001", 
        max_tokens=2000,                      
        messages=[
            {
                "role": "user",
                "content": prompt  
            }
        ]
        )

        task_list = message.content[0].text

        return task_list

    except Exception as e:
        raise Exception(f"Anthropic API error: {str(e)}")
    


def update_tasks_list(verified_tasks):
        
    pass
"""
    Zaproponowac zmiany na najblizszy miesiac ze wzgledu na pogode. Integracja z SNS i email do klienta.
    

    # remove markdown if added by Claude
    task_list_clean = verified_tasks.strip()
    if task_list_clean.startswith("```"):
        task_list_clean = task_list_clean.split("```")[1]
        if task_list_clean.startswith("json"):
            task_list_clean = task_list_clean[4:]

    parsed = json.loads(task_list_clean.strip())
    tasks = parsed['tasks']

"""



