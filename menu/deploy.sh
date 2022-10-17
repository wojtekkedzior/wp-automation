# email comes from a bucket where the email arrive

rm lambda.zip && zip -r lambda.zip * && aws --profile wpuser --region eu-west-1 lambda update-function-code --function-name menuUpdater --zip-file fileb://lambda.zip && sleep 10 && aws --profile wpuser s3 cp email s3://inbound-menu/$(uuid)
