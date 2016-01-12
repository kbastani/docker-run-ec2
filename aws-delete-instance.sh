#!/bin/bash
#title           :aws-delete-instance.sh
#description     :This script is used to delete an EC2 instance from inside a Docker container
#author		       :Bridget Kromhout <bkromhout@pivotal.io>, Kenny Bastani <kbastani@pivotal.io>
#date            :2016-01-11
#version         :0.1
#usage		       :sh ./aws-create-instance.sh
#==============================================================================
set -x -e

export INSTANCE_ID="$(cat ~/instance_id | sed 's/\( -\)//1')"
export PUBLIC_IP="$(cat ~/public_ip | sed 's/\( -\)//1')"

# clean up
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
