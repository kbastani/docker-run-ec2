#!/bin/bash
#title           :ssh-docker-run.sh
#description     :This script is used to run docker commands on a remote EC2 instance from inside a Docker container
#author		       :Bridget Kromhout <bkromhout@pivotal.io>, Kenny Bastani <kbastani@pivotal.io>
#date            :2016-01-11
#version         :0.1
#usage		       :sh ./aws-delete-instance.sh
#==============================================================================
set -x -e

export PUBLIC_IP="$(cat ~/public_ip | sed 's/\( -\)//1')"

ssh -tt -i ~/$PROJECT_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo docker $DOCKER_COMMAND"
