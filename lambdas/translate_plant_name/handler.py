import boto3
import json

client = boto3.client('translate')

def translate_job(plant_name_original):
    
    
    response = client.translate_text(
        Text= plant_name_original,
    
        SourceLanguageCode='auto',
        TargetLanguageCode='en'
    )
      
    eng_plant_name = response['TranslatedText']

    return eng_plant_name

    

def lambda_handler(event, context):
    
    print(f"Event received: {event}")
    # original plant name (could be in any language) we get from json dict (event) comming to lambda
    # both cases - api gateway: body in json stepfunctions : event
    if 'body' in event:
        body = json.loads(event['body'])  # API Gateway
    else:
        body = event  # Step Functions
        
    plant_name_original = body['plant_name']

    #continue with translate_job function
    eng_plant_name = translate_job(plant_name_original)

    return {
        'statusCode': 200,
        'body': eng_plant_name
    }

