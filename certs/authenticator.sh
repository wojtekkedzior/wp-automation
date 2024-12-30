#!/bin/bash

source venv/bin/activate
python -m pip install -r requirements.txt

python /home/wojtek/git/wp-automation/certs/DNSChallenge.py -d $CERTBOT_DOMAIN -c $CERTBOT_VALIDATION

deactivate

