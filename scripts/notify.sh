#!/bin/bash

CLUSTER_ID=$1
CLUSTER_NAME=$2

NOTIFY_URL=$SLACK_WEBHOOK_URL

echo 'payload= {"text":"*CLUSTER: '$CLUSTER_NAME' # '$CLUSTER_ID'*\n>Data load steps are complete. Check for any failed steps."}' > msg.txt
curl -X POST -H 'Content-type: application/x-www-form-urlencoded' --data @msg.txt $NOTIFY_URL
