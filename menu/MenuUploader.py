"""
Created on Apr 13, 2020

@author: wojtek
"""
import boto3
import time
import sys
import argparse

import os
#https://github.com/ikvk/imap_tools
from imap_tools import MailBox

MENU_FILE = "menu.pdf"

def addAttachmentToS3(message, session):
    s3client = session.client("s3")
    cfClient = session.client("cloudfront")

    if(len(message.attachments) == 0 ):
        print(f"No attachments in this message. {message.text}")
    
    print(f"Attachment found. filename is: {message.attachments[0].filename}")
    
    if(not message.attachments[0].filename.endswith(".pdf")):
        print("File not a pdf, so not publishing it")
        sys.exit(1)

    resp = s3client.put_object(
            Body=message.attachments[0].payload, Bucket=os.environ["BUCKET_NAME"], Key=MENU_FILE, 
            Tagging=f"date={message.date.timestamp()}&originalFileName={message.attachments[0].filename}",
        )
    
    print("File has been added.")
    print(resp) 
    
    # CF Invalidation
    fieldToInvalidate = [f"/{MENU_FILE}"]
 
    response = cfClient.create_invalidation(
        DistributionId=os.environ["DISTRIBUTION_ID"],
        InvalidationBatch={
            "Paths": {"Quantity": len(fieldToInvalidate), "Items": fieldToInvalidate},
            "CallerReference": time.time().__str__(),
        },
    )
      
    print(response)
    sys.exit(0)

def updateMenu(session):
    s3client = session.client("s3")
    
    email_user = ""
    email_pass = ""
 
    with MailBox('imap.gmail.com').login(email_user,email_pass, 'INBOX') as mailbox:
        for message in mailbox.fetch(limit=1, reverse=True):

            try :
                resp = s3client.get_object_tagging(
                        Bucket=os.environ["BUCKET_NAME"],
                         Key=MENU_FILE,
                    )
            except: 
                addAttachmentToS3(message, session)
            
            if(len(resp['TagSet']) == 0) :
               #Found a menu, but it';s not been tagged so can't really tell how old it is.  Treating it as if we didn't have one. 
               addAttachmentToS3(message, session)
            
            existingMenuDate = resp['TagSet'][0]['Value']
            
            if(float(existingMenuDate) == message.date.timestamp()):
                print("This menu has been uploaded from this message.")
            elif(float(existingMenuDate) < message.date.timestamp()):
                print("'Email is newer so upload")
                addAttachmentToS3(message, session)
            else:
                print(f"'This shouldn't happen: {existingMenuDate}")
                sys.exit(1)

if __name__ == "__main__":
    session = boto3.Session(profile_name="wpuser")
    updateMenu(session)
    