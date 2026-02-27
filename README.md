# wp-automation
Scripts for WP automation

userful docker command to start my dev db

docker run    --name test-mysql    -v /mnt/k8volumes/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=strong_password  -p 13306:3306 -d mysql:9.0.1 && docker logs  test-mysql -f


docker login:
/usr/local/aws-cli/v2/current/bin/aws --profile <> ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <>.dkr.ecr.eu-west-1.amazonaws.com/<>

/usr/local/aws-cli/v2/current/bin/aws --profile wpuser ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/y7c9l5j8


/usr/local/aws-cli/v2/current/bin/aws --profile wpuser ecr-public get-login-password -
-region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/y7c9l5j8


 sudo sed -i "/setenv HAZELCAST_IP/c\\\tsetenv HAZELCAST_IP $(kubectl get svc my-release-hazelcast -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg