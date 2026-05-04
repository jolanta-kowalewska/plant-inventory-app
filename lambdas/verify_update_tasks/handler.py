import requests
import boto3
import json
import os
import anthropic
from datetime import datetime

def lambda_handler(event, context):
    print(f"Event received: {event}")

    try: 
        ssm = boto3.client('ssm', region_name=os.environ['AWS_REGION'])
        
        #aws ssm get parameter to get api_key for claude and openweather
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

        #get all users
        user_ids = get_users_id()
        message_ids = [] #will be used the get responses after each iteration
        # whole flow for every user we get from Users table
        for user_id in user_ids:
    
            #fetch user location from users table 
            user_profile = get_user_profile(user_id)
            user_location = user_profile['location']   
   
            #next month definition
            month = (datetime.now().month % 12) + 1  # December → 1 (January)

            #fetch current tasks for the user for the next month only from dynamodb table 
            tasks = get_tasks(user_id, month)

            #get current weather prediction in user location
            weather = get_weather(user_location, weather_api_key)

            #use claude agent to verify the tasks for the upcoming month based on weather prognostic
            verified_tasks = verify_tasks_with_claude(tasks, weather, anthropic_api_key, month)

            #TODO update tasks list 

            message_id = send_notification(verified_tasks, user_id)
            message_ids.append(f"{user_id}: {message_id}")

        return {
            'statusCode': 200,
            'body': f"Notifications sent: {len(message_ids)} users notified"
        }

    except Exception as e:
        print(f"Error details: {str(e)}")
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }
    
# Get all users from DynamoDB Users table 
def get_users_id():
    dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USERS'])
    
    response = table.scan(
        ProjectionExpression='user_id'  # get only user_id, not whole record
    )
    
    return [item['user_id'] for item in response['Items']]

def get_tasks(user_id, month):
    from boto3.dynamodb.conditions import Key, Attr
    
    dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])   
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE_GARDEN_TASKS'])

    try:

        # get tasks for a user_id
        response = table.query(
            KeyConditionExpression=Key('user_id').eq(user_id)
        )
        
        # only for upcoming month 
        next_month = str(month).zfill(2)  # i.e "05" for May
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

    # get geolocation (lat and  lon)
    geo_url = f"http://api.openweathermap.org/geo/1.0/direct?q={location}&limit=1&appid={weather_api_key}"
    
    try: 

        geo_response = requests.get(geo_url)
        geo_data = geo_response.json()
        lat = geo_data[0]['lat']
        lon = geo_data[0]['lon']
        
        # get weather for next 5 days
        forecast_url = f"https://api.openweathermap.org/data/2.5/forecast?lat={lat}&lon={lon}&appid={weather_api_key}&units=metric&cnt=40"
        
        forecast_response = requests.get(forecast_url)
        data = forecast_response.json()
        
        return data
    
    except requests.exceptions.RequestException as e:
        raise Exception(f"Perenual API error: {str(e)}")



def verify_tasks_with_claude(tasks, weather, anthropic_api_key, next_month):

    current_year = datetime.now().year

    # get only whats important
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
    


def send_notification(verified_tasks, user_id):
    sns = boto3.client('sns', region_name=os.environ['AWS_REGION'])
    
    response = sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Subject=f"Garden Plan Update Proposal for {user_id}",
        Message=f"Here are the proposed task updates for next month:\n\n{verified_tasks}"
    )
    
    return response['MessageId']

def get_user_profile(user_id):
    
    dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])
    
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE_USERS'])

    response = table.get_item(
        Key = {'user_id': user_id}
    )

    return response['Item']




