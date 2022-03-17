"""
Created on Apr 13, 2020

@author: wojtek
"""
import time
import dns.resolver
import sys
import argparse
from AWSAccount import AWSAccount

class DNSChallenge(AWSAccount): 

    domain = ""
    challenge=""
    delay = None
    route53Client = None
    
    def __init__(self, domain, challenge, delay):
        self.domain = domain
        self.challenge = challenge
        self.delay = delay
        self.route53Client = self.getSession().client("route53")
    
    def _findHostedZone(self):
        resp = self.route53Client.list_hosted_zones()
        
        for hostedZone in resp["HostedZones"]: 
            if (hostedZone['Name'] == (domain+".")):
                return hostedZone['Id']
        
        print("No HostedZone found for: ", domain)
        sys.exit(1)
        
    def _getChallengeURL(self):   
        return "_acme-challenge." + domain
    
    def _requestToRoute53(self, action):
        resp = self.route53Client.change_resource_record_sets(
               HostedZoneId=self._findHostedZone(),
                ChangeBatch={
                    'Comment': 'test RS',
                    'Changes': [
                        {
                            'Action': action, #UPSERT or CREATE or DELETE
                            'ResourceRecordSet': {
                                'Name': self._getChallengeURL(),
                                'Type': 'TXT',
                                'TTL': 1,
                                'ResourceRecords': [
                                    {
                                        'Value': "\"" + challenge +"\"",
                                    },
                                ],
                            }
                        },
                    ]
                }
            )
        
    def handleChallenge(self):
        print("handling ", challenge, "for: ", domain)
        time.sleep(10)
        self._requestToRoute53('UPSERT')
        while True:
            try:
                resp = self.route53Client.test_dns_answer(
                       HostedZoneId=self._findHostedZone(),
                       RecordName=self._getChallengeURL(),
                       RecordType='TXT'               
                    ) 
                
                print("TXT record resolved to: ", resp['RecordData'])
                if (resp['ResponseCode'] == 'NOERROR' and "\"" + challenge +"\"" in resp['RecordData']):
                    break
                
            except self.route53Client.exceptions.NoSuchHostedZone:
                  print("TXT record resolved, but does not have the expected value:. ", dnsTxtRecord)

            print("sleeping...")
            time.sleep(5)
        
        print("Route53 is resolving correctly. waiting ", delay)
        time.sleep(10)
        print("Wait finished")

    def cleanup(self):
        time.sleep(delay)
        self._requestToRoute53('DELETE')
        time.sleep(delay)
            
def parseArgs() :
    description = ""
    epilog = ""
    
    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument( "-d", metavar="Domain", help="The domain", required=True,)
    parser.add_argument( "-c", metavar="Challenge", help="The Challenge", required=True,)
    parser.add_argument( "--cleanup", action="store_true", help="Weather to attempt to clean up the challenge. ",)

    global args
    args = parser.parse_args()       

if __name__ == "__main__":
    parseArgs()

    domain = args.d
    challenge = args.c

    # The lookup with a .cz domain needs more time between challanges.
    if (domain[-3:] == ".cz") :
        delay = 600
    else:
        delay = 60

    print("starting chellenge ", challenge, "for: ", domain)
    dnsChallenge = DNSChallenge(domain, challenge, delay)
    
    if(args.cleanup) :
        dnsChallenge.cleanup()
    else:
        dnsChallenge.handleChallenge()
        
# Note to self: --dry-run is broken.  It always times out even if you use lots of delays, where as the main prod end-point is happy with just a few 30 seconds delays.
# I even managed to get multiple certs (for different domains) without any specific delays, just the one where I'm polling Route53.  Although having to delays in
# when using the main end-point can also result in errors. I can handle 2 minutes per certificate as long as they work!
# i'm also not sure about the usage of --domains "$domain,*.$domain" because this causes two seperate challanges but they are on the same hosted Zone.  In the 'prod'
# endpoint  when u use -d twice, then the same challange is placed on the one hosted zone and therefore resolved really quickly. Something about certbot is weird
        
