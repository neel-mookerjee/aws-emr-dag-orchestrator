#!/bin/bash

COUNTER=$1
WG=$2

wget -O TaskRunner-1.0.jar https://s3.amazonaws.com/datapipeline-us-east-1/us-east-1/software/latest/TaskRunner/TaskRunner-1.0.jar
nohup java -jar TaskRunner-1.0.jar --workerGroup=$WG --region=us-west-2 --logUri=s3://taskrunnerlogs/$COUNTER > log.txt &
