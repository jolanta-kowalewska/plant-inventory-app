import boto3
import json
import os
import anthropic

def lambda_handler(event, context):
    
    try:
        ssm = boto3.client('ssm', region_name=os.environ['AWS_REGION'])

        # original plant name (could be in any language) we get from json dict (event) comming to lambda
        body = json.loads(event['body'])
        plant_name_original = body['plant_name']

        
        #aws ssm get parameter to get api_key for perenual 
        response = ssm.get_parameter(
            Name='/plant-app/dev/anthropic-api-key',
            WithDecryption=True
        )

        api_key = response['Parameter']['Value']

        #continue with translate_job function

        eng_plant_name = translate_job(api_key, plant_name_original)

        return {
            'statusCode': 200,
            'body': eng_plant_name
        }
    
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }

def translate_job(api_key, plant_name_original):
    
    try:
        client = anthropic.Anthropic(api_key=api_key)

        message = client.messages.create(
        model="claude-haiku-4-5-20251001",  # the cheapest option, enough for translate job
        max_tokens=100,                      # 1-2 word so limited token 
        messages=[
            {
                "role": "user",
                "content": f"Please translate the plant name to English. The plant name is {plant_name_original}. Please check first the original language. Return only the name for the plant without any additional text. The value should be string"             # tu wpisujesz swój prompt
            }
        ]
        )

        eng_plant_name = message.content[0].text

        return eng_plant_name

    except Exception as e:
        raise Exception(f"Anthropic API error: {str(e)}")