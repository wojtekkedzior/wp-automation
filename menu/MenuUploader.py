
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
    print("bucket: ", bucket, " key: ", key)

    obj = s3.Object(bucket, key)

    b = email.message_from_string(obj.get()['Body'].read().decode('utf-8') )
    body = ""

    for part in b.walk():
        ctype = part.get_content_type()
        if ctype == 'application/pdf':
            body = part.get_payload(decode=True)  # decode
            break

    o = s3.Object("erawan-menu", key+'.pdf') # TODO this needs to be renamed to menu.pdf
    o.put(Body=body)
    return "yay"