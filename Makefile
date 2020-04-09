AWS_ACCOUNT	:= "12345678901"
IMAGE_NAME	:= "dag-orchestrator"
REPOSITORY_NAME	:= "$(IMAGE_NAME)"
ECR_REPOSITORY	:= "$(AWS_ACCOUNT).dkr.ecr.us-west-2.amazonaws.com/$(REPOSITORY_NAME)"

check-var = $(if $(strip $($1)),,$(error var for "$1" is empty))
STACK_LOWER := $(shell echo $(stack) | tr A-Z a-z)
CLUSTER := $(shell echo $(cluster))
DATA := $(shell echo $(data))
MODE := $(shell echo $(mode))
EXECUTE := $(shell echo $(execute))
RELEASE_CRON := hql-orchestrator-$(STACK_LOWER)-cronjob
RELEASE_JOB := hql-orchestrator-$(STACK_LOWER)-job

default: help

require_tag:
	$(call check-var,tag)

require_stack:
	$(call check-var,stack)

require_cluster:
	$(call check-var,cluster)

require_data:
	$(call check-var,data)

require_mode:
	$(call check-var,mode)

require_execute:
	$(call check-var,execute)


docker/build:		validate_tag ## Build and tag the Docker image. vars:tag
					@docker build -t $(IMAGE_NAME) .
					@docker tag $(REPOSITORY_NAME) $(ECR_REPOSITORY):$(tag)

validate_tag:		require_tag

docker/push:		validate_tag ## Push the Docker image to ECR. vars:tag
					@aws ecr get-login --region us-west-2 --no-include-email | sh -
					@docker push $(ECR_REPOSITORY):$(tag)

helm/cron/install:	require_stack require_cluster require_data require_execute require_mode ## Deploy the cronjob stack into kubernetes. vars: stack, cluster (<cluster id> or 'default'), data ('full' or 'trim'), mode ('full' or 'adhoc'), execute ('step' or 'datapipeline')
					@helm install --name $(RELEASE_CRON) --set CLUSTER=$(CLUSTER) --set DATA=$(DATA) --set MODE=$(MODE) --set EXECUTE=$(EXECUTE) --set STACK=$(STACK_LOWER) ./charts/cronchart

helm/cron/delete:	require_stack ## Delete the cronjob stack from kubernetes. vars: stack
					@helm delete --purge $(RELEASE_CRON)

helm/job/install:	require_stack require_cluster require_data require_execute require_mode ## Deploy the job (on demand) stack into kubernetes. vars: stack, cluster (<cluster id> or 'default'), data ('full' or 'trim'), mode ('full' or 'adhoc'), execute ('step' or 'datapipeline')
					@helm install --name $(RELEASE_JOB) --set CLUSTER=$(CLUSTER) --set DATA=$(DATA) --set MODE=$(MODE) --set EXECUTE=$(EXECUTE) --set STACK=$(STACK_LOWER) ./charts/jobchart

helm/job/delete:	require_stack ## Delete the job stack from kubernetes. vars: stack
					@helm delete --purge $(RELEASE_JOB)

help:				## This helps
					@awk 'BEGIN {FS = ":.*?## "} /^[\/a-zA-Z_-]+:.*?## / {sub("\\\\n",sprintf("\n%22c"," "), $$2);printf "\033[36mdag-orchestrator \033[0m%-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
