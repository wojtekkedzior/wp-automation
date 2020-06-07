#!/bin/bash

while getopts sd:e: option
do
    case "${option}"  in
        s) skipCert_flag=true ;;
        d) domain=$OPTARG ;;
        e) email=$OPTARG ;;
    esac
done

echo "skipcert: " $skipCert_flag
echo "domain: " $domain
echo "email: " $email

#if [[ 1 -lt 0 ]]  ; then 
echo 2 | \
certbot certonly \
            --logs-dir /opt/certbot/logs \
            --config-dir /opt/certbot/config \
            --work-dir /opt/certbot/work  \
            --manual-auth-hook certs/authenticator.sh \
            --manual-cleanup-hook certs/cleanup.sh \
            --manual-public-ip-logging-ok \
            --agree-tos  \
            --preferred-challenges dns \
            --manual \
            -m $email \
            --domains "*.$domain, $domain" && {
                    # Create or update certificate in ACM 
                    python3 updateCertManager.py $domain && {
                            # Upload certificate to EC2
                            scp -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/cert.pem  ec2-user@backend.$domain:
                            scp -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/fullchain.pem  ec2-user@backend.$domain:
                            scp -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/privkey.pem ec2-user@backend.$domain:
                            
                            # Restart httpd
                            ssh -i $AWS_SSH_KEY ec2-user@backend.$domain "sudo service httpd restart"
                            ssh -i $AWS_SSH_KEY ec2-user@backend.$domain "sudo service httpd status"
                    } || {
                        echo "Something went wrong"
                        exit 1
                    }
            } || {
                echo "Something went wrong"
                exit 1
            }
            
#fi            






#TODO have to do this before we do anything!
#  sudo systemd-resolve --flush-caches
         
            
            
            
