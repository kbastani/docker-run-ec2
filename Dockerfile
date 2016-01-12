FROM ubuntu
MAINTAINER Kenny Bastani <kb@socialmoon.com>

RUN apt-get update -y
RUN apt-get install python -y
RUN apt-get install python-pip -y
RUN apt-get install groff -y
RUN apt-get install ssh -y
RUN apt-get install netcat-traditional -y
RUN pip install awscli
ENV AWS_ACCESS_KEY_ID="replace"
ENV AWS_SECRET_ACCESS_KEY="replace"
ENV AWS_DEFAULT_REGION="us-west-2"
ENV PROJECT_NAME="docker-run-ec2"
RUN mkdir /aws
WORKDIR /aws
COPY ./aws-create-instance.sh /aws
COPY ./aws-delete-instance.sh /aws
COPY ./ssh-docker-run.sh /aws
