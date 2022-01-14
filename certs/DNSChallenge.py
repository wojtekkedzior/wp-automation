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
    route53Client = None
    
    def __init__(self, domain, challenge):
        self.domain = domain
        self.challenge = challenge
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
        self._requestToRoute53('UPSERT')
        
        while True:
            try:
                resp = self.route53Client.test_dns_answer(
                       HostedZoneId=self._findHostedZone(),
                       RecordName=self._getChallengeURL(),
                       RecordType='TXT'               
                    ) 
                
                if (resp['ResponseCode'] == 'NOERROR' and "\"" + challenge +"\"" in resp['RecordData']):
                    break
                
            except self.route53Client.exceptions.NoSuchHostedZone:
                  print("TXT record resolved, but does not have the expected value:. ", dnsTxtRecord)
            
            time.sleep(5)
        
        print("Route53 is resolving correctly. waiting 2 minutes...")
        time.sleep(120)

    def cleanup(self):
        self._requestToRoute53('DELETE')

            
def parseArgs() :
    description = ""
    epilog = ""
    
    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument( "-d", metavar="Domain", help="The domain", required=True,)
    parser.add_argument( "-c", metavar="Challenge", help="The Challenge", required=True,)
    parser.add_argument( "--cleanup", action="store_true", help="Weather to attempt to clean up the challenge. ",)
    parser.add_argument('--skip-certificates', action="store_true", help='Skip creation of certificates and just upload existing ones')

    global args
    args = parser.parse_args()       

if __name__ == "__main__":
    parseArgs()

    # This is a limitation of Let's encrypt that it  does not include the root domain when asking for a wild card certificate.  This means we need to request two domains,
    #  but the challenge TXT record is set on the root.  
    # if (args.d[0] == "*") :
    #     domain = args.d[2:]
    # else :
    #     domain = args.d

    domain = "*."+args.d
        
    challenge = args.c;
    dnsChallenge = DNSChallenge(domain, challenge)
    
    if(args.cleanup) :
        dnsChallenge.cleanup()
    else:
        dnsChallenge.handleChallenge()
