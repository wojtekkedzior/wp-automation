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


if [[ $skipCert_flag == false ]] ; then
    echo 2 | \
        certbot certonly \
            --config-dir /opt/certbot/config \
            --logs-dir     /opt/certbot/logs \
            --work-dir   /opt/certbot/work  \
            --agree-tos  \
            --domains "*.$domain, $domain" \
            -m $email \
            --manual \
            --manual-auth-hook       ./authenticator.sh \
            --manual-cleanup-hook ./cleanup.sh \
            --manual-public-ip-logging-ok \
            --preferred-challenges dns && {
                echo "cert created"
            } || {
                echo "Failed to create a new certificate"
                exit 1
            }
fi

python3 updateCertManager.py $domain && {
    # Upload certificate to EC2
    echo "Start copying keys..."
    scp -oStrictHostKeyChecking=no  -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/cert.pem  ec2-user@backend.$domain: 
    scp -oStrictHostKeyChecking=no  -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/fullchain.pem  ec2-user@backend.$domain:
    scp -oStrictHostKeyChecking=no  -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/privkey.pem ec2-user@backend.$domain: 
    echo "Finished copying keys."                        
    # Restart httpd
    ssh -oStrictHostKeyChecking=no -i $AWS_SSH_KEY ec2-user@backend.$domain "sudo service httpd restart"
    ssh -oStrictHostKeyChecking=no -i $AWS_SSH_KEY ec2-user@backend.$domain "sudo service httpd status"
} || {
    echo "Something went wrong"
    exit 1
}

            
#TODO have to do this before we do anything!
#  sudo systemd-resolve --flush-caches
         
            
            
            
