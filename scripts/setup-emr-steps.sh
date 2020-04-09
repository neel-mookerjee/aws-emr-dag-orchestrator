#!/bin/bash

# Habe the list ready first in order.list
# find . -name '*.sql' -print | grep -e hive
# Maintain dependency

CLUSTER_ID=$1
CLUSTER_NAME=$2
MODE=$3

NOTIFY_URL=$SLACK_WEBHOOK_URL

handle_error(){
    if [ $1 != 0 ]; then
        echo $2
        echo 'payload= {"text":"*CLUSTER: '$CLUSTER_NAME' # '$CLUSTER_ID'*\n>'$2'"}' > msg.txt
        curl -X POST -H 'Content-type: application/x-www-form-urlencoded' --data @msg.txt $NOTIFY_URL
        exit 1
    fi
}

APPEND=""
# default is the cron file name
if [ "$MODE" == "adhoc" ]; then
    APPEND=".adhoc"
fi

echo "Copying sqls..."
while read F; do
    aws s3 cp $F s3://scripts/hqls/$F
    handle_error $? "Error while copying the sql files to S3. Exiting."
done < hive-modules/loadsequence/steps.sequence$APPEND
echo "Completed"

echo "Copying notify.sh..."
aws s3 cp /notify.sh s3://scripts/notify.sh
handle_error $? "Error while copying the script file to S3. Exiting."

echo "Creating emr steps..."
while read F; do
    sleep 2s
    aws emr --region=us-west-2 add-steps --cluster-id $CLUSTER_ID --steps Name="$F",Jar="command-runner.jar",Type=HIVE,,Args=[-f,s3://scripts/hqls/$F]
    handle_error $? "Error while creating emr step. Exiting."
done < hive-modules/loadsequence/steps.sequence$APPEND

echo "Adding notify step..."
sleep 2s
aws emr --region=us-west-2 add-steps --cluster-id $CLUSTER_ID --steps Name="Notify",Jar=s3://us-west-2.elasticmapreduce/libs/script-runner/script-runner.jar,Type=CUSTOM_JAR,Args=["s3://scripts/notify.sh","$CLUSTER_ID","$CLUSTER_NAME"]
handle_error $? "Error while creating emr step. Exiting."

echo "EMR Steps execution initiated."
