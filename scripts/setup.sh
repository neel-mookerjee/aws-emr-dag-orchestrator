#!/bin/bash

CLUSTER=$1
DATA=$2
MODE=$3
EXECUTE=$4
STACK=$5

NOTIFY_URL=$SLACK_WEBHOOK_URL

handle_error(){
    if [ $1 != 0 ]; then
        echo $2
        echo 'payload= {"text":"*CLUSTER: '$CLUSTER_NAME' # '$CLUSTER'*\n>'$2'"}' > msg.txt
        curl -k -X POST -H 'Content-type: application/x-www-form-urlencoded' --data @msg.txt $NOTIFY_URL
        exit 1
    fi
}

if [[ -z $DATA ]] || [[ -z $CLUSTER ]]; then
    handle_error 1 "CLUSTER (cluster id for emr ['dafault' for the daily one]) and DATA ('full' or 'trim') must be supplied. Exiting."
fi
if [ "$DATA" != "full" ] && [ "$DATA" != "trim" ]; then
    handle_error 1 "Invalid data option: $DATA - must be 'full' OR 'trim'"
fi
if [ "$MODE" != "full" ] && [ "$MODE" != "adhoc" ]; then
    handle_error 1 "Invalid mode option: $MODE - must be 'full' OR 'adhoc'"
fi
if [ "$EXECUTE" != "step" ] && [ "$EXECUTE" != "datapipeline" ]; then
    handle_error 1 "Invalid execution option: $EXECUTE - must be 'step' OR 'datapipeline'"
fi

CLUSTER_IP=""
CLUSTER_NAME=""
DEFAULT="N"
if [ "$CLUSTER" == "default" ]; then
    DEFAULT="Y"
    aws emr list-clusters --active --region us-west-2 > ./output.txt 2>&1
    if [ $? != 0 ]; then
        RESPONSE=`cat output.txt`
        if [ "$(echo $RESPONSE | grep 'Unable to locate credentials')" != "" ] || [ "$(echo $RESPONSE | grep 'exception')" != "" ]; then
            echo "Crappy pod you got! Exiting."
            exit 1
        else
            handle_error 1 "Cluster details could not be retrieved. Exiting."
        fi
    fi
    CLUSTER=`cat ./output.txt | jq '.Clusters[] | select(.Name == "emr-cluster") | .Id' | sed s/\"//g`
fi

echo CLUSTER: $CLUSTER
echo DATA: $DATA
echo MODE: $MODE
echo EXECUTE: $EXECUTE
echo STACK: $STACK

if [[ -z $CLUSTER ]]; then
    handle_error 1 "Cluster Id could not be retrieved. Exiting."
fi

CLUSTER_IP=`aws emr list-instances --region us-west-2 --cluster-id $CLUSTER --instance-group-types MASTER | jq '.Instances[] |  .PrivateIpAddress' | sed s/\"//g`
handle_error $? "Error in getting cluster details. Exiting."
if [[ -z $CLUSTER_IP ]]; then
    handle_error 1 "Cluster IP could not be retrieved. Exiting."
fi

CLUSTER_NAME=`aws emr describe-cluster --region us-west-2 --cluster-id $CLUSTER | jq '.Cluster.Name' | sed s/\"//g`
handle_error $? "Error in getting cluster details. Exiting."
if [[ -z $CLUSTER_NAME ]]; then
    handle_error 1 "Cluster Name could not be retrieved. Exiting."
fi

echo -e "Host github.com\arghanil\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config

echo "Cloning parent Git repo..."
git clone git@github.com:arghanil/hive-modules.git
handle_error $? "Error in cloning the parent Git repo. Exiting."

echo "Cloning submodule Git repo..."
git clone git@github.com:arghanil/other-modules.git
handle_error $? "Error in cloning the submodule Git repo. Exiting."

if [ $DATA == "trim" ]; then
    echo "Altering S3 path for trimmed data..."
    find . -name '*.sql' -exec sed -i 's/tmp01_dataroot/tmp02_dataroot/g' {} \;
fi

echo "Checking if the required S3 bucket exists..."
aws s3 ls s3://scripts --region us-west-2
if [ $? != 0 ]; then
    echo "Trying to create S3 bucket scripts..."
    aws s3 mb s3://scripts --region us-west-2
    handle_error $? "Error while creating required S3 bucket. Exiting."
fi

echo 'payload= {"text":"*CLUSTER: '$CLUSTER_NAME' # '$CLUSTER'*\n>Private IP:'$CLUSTER_IP'\n>Hue URL: http://'$CLUSTER_IP':8888/\n>r53: http://'$CLUSTER_NAME'.nonprod.r53.domain.net:8888/\n>*'$EXECUTE' creation process initiated.*"}' > msg.txt
curl -X POST -H 'Content-type: application/x-www-form-urlencoded' --data @msg.txt $NOTIFY_URL

MSG=""
if [ $EXECUTE == "steps" ]; then
    MSG="Steps generation process completed. Check progress under AWS EMR Steps."
    bash setup-emr-steps.sh $CLUSTER $CLUSTER_NAME $MODE
    if [ $? != 0 ]; then
        MSG="Steps generation process finished with *ERROR*. Check k8 logs and progress under AWS Data Pipeline."
    fi
fi
if [ $EXECUTE == "datapipeline" ]; then
    MSG="Pipeline creation process completed. Check progress under AWS Data Pipeline."
    bash setup-datapipeline.sh $CLUSTER $CLUSTER_NAME $MODE $STACK
    if [ $? != 0 ]; then
        MSG="Pipeline creation process finished with *ERROR*. Check k8 logs and progress under AWS Data Pipeline."
    fi
fi

echo 'payload= {"text":"*CLUSTER: '$CLUSTER_NAME' # '$CLUSTER'*\n>'$MSG'"}' > msg.txt
curl -k -X POST -H 'Content-type: application/x-www-form-urlencoded' --data @msg.txt $NOTIFY_URL
