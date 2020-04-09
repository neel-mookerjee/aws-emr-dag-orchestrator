FROM gliderlabs/alpine:3.3

RUN apk --no-cache add git bash openssh

RUN \
	mkdir -p /aws && \
	apk -Uuv add groff less python py-pip && \
	pip install awscli && \
	apk --purge -v del py-pip && \
	rm /var/cache/apk/*

RUN apk --no-cache add jq

RUN mkdir -p /root/.ssh

COPY scripts/setup.sh /
COPY scripts/setup-emr-steps.sh /
COPY scripts/setup-datapipeline.sh /
COPY scripts/create-task-runner.sh /
COPY scripts/notify.sh /

WORKDIR /
