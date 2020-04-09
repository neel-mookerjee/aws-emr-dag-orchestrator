#!/bin/bash

CLUSTER_ID=$1
CLUSTER_NAME=$2
MODE=$3
STACK=$4

NOTIFY_URL=$SLACK_WEBHOOK_URL

handle_error(){
    if [ $1 != 0 ]; then
        echo $2
        echo 'payload= {"text":"*CLUSTER: '$CLUSTER_NAME' # '$CLUSTER_ID'*\n>'$2'"}' > msg.txt
        curl -X POST -H 'Content-type: application/x-www-form-urlencoded' --data @msg.txt $NOTIFY_URL
        exit 1
    fi
}

find . -path "*.hive*.sql" | sed s/'^.\/'// > file.list
echo "Copying sqls..."
while read F; do
    aws s3 cp $F s3://scripts/hqls/$F
    handle_error $? "Error while copying the sql files to S3. Exiting."
done < file.list
echo "Completed"

echo "Copying create-task-runner.sh..."
aws s3 cp /create-task-runner.sh s3://scripts/create-task-runner.sh
handle_error $? "Error while copying the script file to S3. Exiting."

echo "Creating emr steps for task runner..."
DT=`date +%s`
WORKER_GROUP="EmrWorkerGroup-$DT"
echo "Worker Group: "$WORKER_GROUP
TASK_RUNNER_COUNT=1
COUNTER=1
while [  $COUNTER -le $TASK_RUNNER_COUNT ]; do
    aws emr --region=us-west-2 add-steps --cluster-id $CLUSTER_ID --steps Name="Install Task Runner $COUNTER",Jar=s3://us-west-2.elasticmapreduce/libs/script-runner/script-runner.jar,Type=CUSTOM_JAR,Args=["s3://scripts/create-task-runner.sh","$COUNTER","$WORKER_GROUP"]
    handle_error $? "Error while creating emr step. Exiting."
    sleep 2s
    let COUNTER=COUNTER+1
done

create_pipeline(){
    LOAD_TYPE=$1
    DT=$2
    CLUSTER=$3
    echo "Creating new data pipeline for $LOAD_TYPE data..."
    PIPELINE_ID=`aws datapipeline create-pipeline --region=us-west-2 --name data-pipeline-$STACK-$LOAD_TYPE --unique-id data-pipeline-$STACK-$LOAD_TYPE-$DT | jq '.pipelineId' | sed s/\"//g`
    echo $PIPELINE_ID
    handle_error $? "Error in creating $LOAD_TYPE data pipeline. Exiting."

    echo "New $LOAD_TYPE Pipeline Id: $PIPELINE_ID"

    echo "Uploading pipeline definition..."
    aws datapipeline put-pipeline-definition --region=us-west-2 --pipeline-id $PIPELINE_ID --pipeline-definition file://hive-modules/loadsequence/$LOAD_TYPE.datapipeline.dag.json --parameter-values myWorkerGroup=$WORKER_GROUP myClusterId=$CLUSTER
    handle_error $? "Error in uploading $LOAD_TYPE data pipeline. Exiting."

    aws datapipeline activate-pipeline --region=us-west-2 --pipeline-id $PIPELINE_ID
    handle_error $? "Error in activating $LOAD_TYPE data pipeline. Exiting."
}

DT_CONST=`date +%s`

if [ "$MODE" == "adhoc" ]; then
    create_pipeline "adhoc" $DT_CONST $CLUSTER_ID
else
    create_pipeline "master" $DT_CONST $CLUSTER_ID
    create_pipeline "child" $DT_CONST $CLUSTER_ID
fi

echo "Data Pipeline activated."
