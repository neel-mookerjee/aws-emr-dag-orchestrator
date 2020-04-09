# Eliminatory HQL EMR Steps / Data Pipeline Generator

Creates EMR Steps on the EMR Cluster or Data Pipeline to execute Hive SQLs.

The K8 job downloads the latest master from a repo and creates EMR Steps / Data Pipeline in the EMR Cluster provided.

This file is present in places both for the cronjob and the chart for the ad hoc on demand job.

## Commands
```
hql-orchestrator   docker/build         Build and tag the Docker image. vars:tag
hql-orchestrator   docker/push          Push the Docker image to ECR. vars:tag
hql-orchestrator   helm/cron/install    Deploy the cronjob stack into kubernetes. vars: stack, cluster (<cluster id> or 'default'), data ('full' or 'trim'), mode ('full' or 'adhoc'), execute ('step' or 'datapipeline')
hql-orchestrator   helm/cron/delete     Delete the cronjob stack from kubernetes. vars: stack
hql-orchestrator   helm/job/install     Deploy the job (on demand) stack into kubernetes. vars: stack, cluster (<cluster id> or 'default'), data ('full' or 'trim'), mode ('full' or 'adhoc'), execute ('step' or 'datapipeline')
hql-orchestrator   helm/job/delete      Delete the job stack from kubernetes. vars: stack
hql-orchestrator   help                 This helps
```

### Schedule Job To Generate EMR Steps / AWS Data Pipeline on the Cluster
```
make helm/cron/install stack=poc cluster=default data=trim mode=full execute=step
```

| Name | Description  |
|------|--------------|
| `stack` | A name to identify your stack, e.g. poc; this will resolve into `hql-steps-generator-<stack is lowercase>-cronjob` |
| `cluster` | `<cluster id>` or `default` for mode emr, `<master node ip>` for bash |
| `data` | `full` for the entire S3 data set under `tmp01_dataroot`, `trim` for the trimmed data set under `tmp02_dataroot` |
| `mode` | `full` to run all the DAGs or Steps, `adhoc` to run the `adhoc` DAG or Step sequence file |
| `execute` | `step` to create AWS EMR Steps (sequential), `datapipeline` for AWS Data Pipeline (DAG) |

### Delete Cronjob
```
make helm/cron/delete stack=poc
```

### Run an Ad hoc To Generate EMR Steps / Data Pipeline on the Cluster
```
make helm/job/install stack=adhoc cluster=default data=trim mode=adhoc execute=datapipeline
```

> **Note: This downloads the latest SQLs and creates the steps. As the SQLs have CREATE IF NOT EXIST option applied, you need to DROP your tables in order to see your changes reflected in the Hive Cluster.**


### Delete Ad hoc Job
```
make helm/job/delete stack=adhoc
```
