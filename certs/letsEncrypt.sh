source /home/wojtek/.basheditor/remote-debugging-v1.sh localhost 33333 #BASHEDITOR-TMP-REMOTE-DEBUGGING-END|Origin line:#!/bin/bash

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
#echo 2 | \
#certbot certonly \
#            --logs-dir /home/wojtek/Documents/certbot/logs \
 #           --config-dir /home/wojtek/Documents/certbot/config \
 #           --work-dir /home/wojtek/Documents/certbot/work  \
  #          --manual-auth-hook ./authenticator.sh \
    #        --manual-cleanup-hook ./cleanup.sh \
      #      --manual-public-ip-logging-ok \
        #    --agree-tos  \
          #  --preferred-challenges dns \
           # --manual \
            #-m $email \
            #--domains "*.$domain, $domain" && {
                    # Create or update certificate in ACM 
               #     python3 updateCertManager.py $domain && {
                            # Upload certificate to EC2
                            echo $AWS_SSH_KEY
                            scp -oStrictHostKeyChecking=no -v -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/cert.pem  ec2-user@backend.$domain:
                            scp -oStrictHostKeyChecking=no -v -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/fullchain.pem  ec2-user@backend.$domain:
                            scp -oStrictHostKeyChecking=no -v -i $AWS_SSH_KEY /opt/certbot/config/live/$domain/privkey.pem ec2-user@backend.$domain:
                            
                            # Restart httpd
                            ssh -oStrictHostKeyChecking=no -i $AWS_SSH_KEY ec2-user@backend.$domain "sudo service httpd restart"
                            ssh -oStrictHostKeyChecking=no -i $AWS_SSH_KEY ec2-user@backend.$domain "sudo service httpd status"
                  #  } || {
                     #   echo "Something went wrong"
                        #exit 1
                    #}
           # } || {
             #   echo "Something went wrong"
               # exit 1
           # }
            
#fi            






#TODO have to do this before we do anything!
#  sudo systemd-resolve --flush-caches
         
            
            
            
