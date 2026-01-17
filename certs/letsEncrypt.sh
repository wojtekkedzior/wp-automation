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
            -v \
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

                /home/wojtek/Downloads/aws/dist/aws --profile wpuser ec2 allocate-address --domain vpc

                publicIp=$(/home/wojtek/Downloads/aws/dist/aws --profile wpuser ec2 describe-addresses | jq -r '.Addresses[0].PublicIp')
                allocationId=$(/home/wojtek/Downloads/aws/dist/aws --profile wpuser ec2 describe-addresses | jq -r '.Addresses[0].AllocationId')

                /home/wojtek/Downloads/aws/dist/aws --profile wpuser ec2 associate-address --network-interface-id eni-0225b596285f1b1d7 --allocation-id  $allocationId

                associationId=$(/home/wojtek/Downloads/aws/dist/aws --profile wpuser ec2 describe-addresses | jq -r '.Addresses[0].AssociationId')

                # wait for the public IP to get applied. Normally this is very quick
                sleep 10

                echo "Start copying keys..."
                scp -oStrictHostKeyChecking=no -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/cert.pem       ec2-user@$publicIp:$domain
                scp -oStrictHostKeyChecking=no -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/fullchain.pem  ec2-user@$publicIp:$domain
                scp -oStrictHostKeyChecking=no -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/privkey.pem    ec2-user@$publicIp:$domain
                echo "Finished copying keys."                        
                ssh -oStrictHostKeyChecking=no -i $AWS_SSH_KEY ec2-user@$publicIp "sudo service httpd restart"
                ssh -oStrictHostKeyChecking=no -i $AWS_SSH_KEY ec2-user@$publicIp "sudo service httpd status"
                echo "Finished restarting"

                # remove the public IP
                /home/wojtek/Downloads/aws/dist/aws --profile wpuser ec2 disassociate-address --association-id $associationId
                /home/wojtek/Downloads/aws/dist/aws --profile wpuser ec2 release-address --allocation-id $allocationId

                deactivate

                echo -e "new certificate for $domain uploaded. \n\n\n\n"

            } || {
                echo -e "Failed to create a new certificate for $domain. \n\n\n\n"
                deactivate
                exit 1
            }
fi