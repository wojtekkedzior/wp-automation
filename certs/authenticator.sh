#!/bin/bash

echo $CERTBOT_DOMAIN
echo $CERTBOT_VALIDATION
echo $CERTBOT_TOKEN
echo $CERTBOT_REMAINING_CHALLENGES
echo $CERTBOT_ALL_DOMAINS
echo $CERTBOT_AUTH_OUTPUT

python3 DNSChallenge.py -d $CERTBOT_DOMAIN  -c $CERTBOT_VALIDATION > file

cat file

echo $CERTBOT_AUTH_OUTPUT

