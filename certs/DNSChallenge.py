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
        print("Setting a challenge value: ", challenge)
        
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
                                'SetIdentifier': 'string',
                                'Weight': 1,
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
            print("trying to resolve query")
            try:
                dnsTxtRecord = dns.resolver.query(self._getChallengeURL(),"TXT").response.answer[0][0].to_text()
                print("resolver output: ", dnsTxtRecord)
                if(("\"" + challenge +"\"") == dnsTxtRecord) :
                    print("Records match. Challenge: ", "\"" + challenge +"\"" , " dnsTXT: ", dnsTxtRecord)
                    break
                print("TXT record resolved, but does not have the expected value:. ", dnsTxtRecord)
            except dns.resolver.NXDOMAIN:
                    print ("No such domain") 
            except dns.resolver.Timeout:
                print("Waiting for the TXT record to resolve: ", self._getChallengeURL(), " ", RuntimeError)
            except dns.exception.DNSException:
                print ("Unhandled exception") 
            
            time.sleep(5)

        print("TXT record contains: ", dnsTxtRecord, "Waiting for a minute to give ACME enough time to query the challenge and validate it.")    
        # The Challenge TXT record is there and resolved locally, so now need to wait for ACME to hit it.  We won't knot when that will happen so this is a best-guess value.
        # Without a timeout here ACME won't have enough time to validate the challenge and the request will thus fail.  The danger here is that we may end up hitting some timeouts.        
        time.sleep(60)    
        

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
    if (args.d[0] == "*") :
        domain = args.d[2:]
    else :
        domain = args.d
        
    challenge = args.c;

    dnsChallenge = DNSChallenge(domain, challenge)
#    debugging 
#     dnsChallenge.handleChallenge()
    
    if(args.cleanup) :
        dnsChallenge.cleanup()
    else:
        dnsChallenge.handleChallenge()
