"""
Created on Apr 13, 2020

@author: wojtek
"""
import sys
from AWSAccount import AWSAccount

class UpdateCertManager(AWSAccount):
    
    def handleChallenege(self):
        acmClient =self.getSession().client("acm")
    
        resp = acmClient.list_certificates(
            CertificateStatuses=["ISSUED", "EXPIRED"],
        )

        print("Found: ", len(resp["CertificateSummaryList"]),  " certificates")
        domain = sys.argv[1]
        print("Adding *. and Looking for: ", domain)
        
        certArn = None
        for cert in resp["CertificateSummaryList"]:
            if( cert["DomainName"] == ("*." + domain)):
                certArn = cert["CertificateArn"]
                break
        
        if(certArn is None):
            print("No certificate found")
            exit(1)
            
        print("Certificate ARN: ", certArn)   
        
        with open('/opt/certbot/config/live/'+domain+'/cert.pem' ) as file:
            publicPem = file.read()
            
        with open('/opt/certbot/config/live/'+domain+'/fullchain.pem' ) as file:
            fullChainPem = file.read()
            
        with open('/opt/certbot/config/live/'+domain+'/privkey.pem' ) as file:
            privatePem = file.read()    
            
        response = acmClient.import_certificate(
            CertificateArn=certArn,
            Certificate=publicPem,
            PrivateKey=privatePem,
            CertificateChain=fullChainPem,
        )
        
        print(response)

if __name__ == "__main__":
    ucm = UpdateCertManager()

    ucm.handleChallenege()
