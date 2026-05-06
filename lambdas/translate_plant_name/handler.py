import boto3
import json
import anthropic

ssm = boto3.client('ssm')

def translate_job(api_key, plant_name_original):

    client = anthropic.Anthropic(api_key=api_key)

    message = client.messages.create(
    model="claude-haiku-4-5-20251001",  # the cheapest option, enough for translate job
     max_tokens=100,                      # 1-2 word so limited token 
    messages=[
        {
            "role" : "user",
            "content" : f"Translate this plant name to English. Return ONLY the English name, nothing else. If already in English, return as-is. Plant name: {plant_name_original}"
        }
    ]
    )
    eng_plant_name = message.content[0].text

    return eng_plant_name


def lambda_handler(event, context):
    
    # original plant name (could be in any language) we get from json dict (event) comming to lambda
    # both cases - api gateway: body in json stepfunctions : event
    if 'body' in event:
        body = json.loads(event['body'])  # API Gateway
    else:
        body = event  # Step Functions
        
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
    
    


    
    
        

    