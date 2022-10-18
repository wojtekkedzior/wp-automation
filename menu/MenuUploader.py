
# """
# Created on Apr 13, 2020

# @author: wojtek
# """
import boto3
import email

def lambda_handler(event, context):
    s3 = boto3.resource('s3')

    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    obj = s3.Object(bucket, key)

    for part in email.message_from_string(obj.get()['Body'].read().decode('utf-8') ).walk():
        ctype = part.get_content_type()
        if ctype == 'application/pdf':
            s3.Object("erawan-menu", 'menu.pdf').put(Body=part.get_payload(decode=True))
            break