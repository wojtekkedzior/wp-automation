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

if [[ -z $skipCert_flag ]] ; then
    source venv/bin/activate
    python -m pip install -r requirements.txt

    echo 2 | \
        /snap/bin/certbot certonly \
            --config-dir /opt/certbot/config \
            --logs-dir /opt/certbot/logs \
            --work-dir /opt/certbot/work  \
            --agree-tos  \
            --cert-name "$domain" \
            -d "$domain" \
            -d "*.$domain" \
            -m $email \
            --manual \
            --manual-auth-hook /home/wojtek/git/wp-automation/certs/authenticator.sh \
            --manual-cleanup-hook /home/wojtek/git/wp-automation/certs/cleanup.sh \
            --preferred-challenges dns && {
                echo "cert created"
            } || {
                echo "Failed to create a new certificate"
                deactivate
                exit 1
            }
fi

echo "Start copying keys..."
scp -oStrictHostKeyChecking=no -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/cert.pem       ec2-user@backend.$domain:$domain
scp -oStrictHostKeyChecking=no -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/fullchain.pem  ec2-user@backend.$domain:$domain
scp -oStrictHostKeyChecking=no -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/privkey.pem    ec2-user@backend.$domain:$domain
echo "Finished copying keys."                        
ssh -oStrictHostKeyChecking=no -i $AWS_SSH_KEY ec2-user@backend.$domain "sudo service httpd restart"
ssh -oStrictHostKeyChecking=no -i $AWS_SSH_KEY ec2-user@backend.$domain "sudo service httpd status"
echo "Finished restarting"

deactivate