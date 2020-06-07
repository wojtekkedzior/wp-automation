import boto3

    
class AWSAccount:

    def __init__(self):
        print("self")
        
    def getSession(self):
        return boto3.Session(profile_name="wpuser", region_name="us-east-1")
