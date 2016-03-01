#!/bin/bash
#title           :aws-create-instance.sh
#description     :This script is used to create an ephemeral EC2 instance with Docker Compose installed.
#author		       :Bridget Kromhout <bkromhout@pivotal.io>, Kenny Bastani <kbastani@pivotal.io>
#date            :2016-01-11
#version         :0.1
#usage		       :sh ./aws-create-instance.sh
#==============================================================================
set -x -e

# Get the host machine's public IP for security group authorization
HOST_IP=$(wget http://ipinfo.io/ip -qO -)

# clean up keypair if it exists. Still exits 0 if it didn't exist, for some reason.
aws ec2 delete-key-pair --key-name $PROJECT_NAME

# The next line will throw an error if it can't delete the group because it has a running instance:
# A client error (DependencyViolation) occurred when calling the DeleteSecurityGroup operation: resource sg-eaa4a08e has a dependent object
# If the group exists and is in use we'll actually bail out later (when trying to create the group) because I do want to continue if the error is "you're trying to delete something that doesn't exist in the first place"
aws ec2 delete-security-group --group-name $PROJECT_NAME || true

# We don't want to keep the previous pem around. A bit fragile if we're in the corner case of "we shouldn't have run this script and still need to access a previously launched instance", so TODO: fix that before going beyond testing with this.
rm ~/$PROJECT_NAME.pem || true

# make a new $PROJECT_NAME keypair to ensure we have the pem
aws ec2 create-key-pair --key-name $PROJECT_NAME --query 'KeyMaterial' --output text > ~/$PROJECT_NAME.pem
chmod 600 ~/$PROJECT_NAME.pem

# make a new security group any IP can ssh into
aws ec2 create-security-group --group-name $PROJECT_NAME --description $PROJECT_NAME
aws ec2 authorize-security-group-ingress --group-name $PROJECT_NAME --ip-permissions "[{\"IpProtocol\": \"tcp\", \"FromPort\": 0, \"ToPort\": 65535, \"IpRanges\": [{\"CidrIp\": \"$HOST_IP/24\"}]}]"

# launch instance with ubuntu AMI for us-west-2
# there are assumptions here, about the default region you have set and the instance type you're launching. To whit: not all instance types can be used with all AMIs, and AMIs are region-specific.
aws ec2 run-instances --image-id ami-f0091d91 --key-name $PROJECT_NAME --instance-type "$EC2_INSTANCE_TYPE" --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":80,\"DeleteOnTermination\":true}}]" --security-groups $PROJECT_NAME

# get public IP of instance when it has one
#
# This will loop until it gets an IP, with output eventually ending like this:
#
# ++ aws ec2 describe-instances --filter Name=key-name,Values=$PROJECT_NAME Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[PublicIpAddress]' --output text
# + PUBLIC_IP=
# + '[' -z '' ']'
# + sleep 1
# ++ aws ec2 describe-instances --filter Name=key-name,Values=$PROJECT_NAME Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[PublicIpAddress]' --output text
# + PUBLIC_IP=52.26.154.169
# + '[' -z 52.26.154.169 ']'

while [ -z "${PUBLIC_IP}" ]; do
  sleep 1
  PUBLIC_IP=$(aws ec2 describe-instances --filter Name="key-name",Values="$PROJECT_NAME" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[PublicIpAddress]' --output text)
done

echo $PUBLIC_IP -> ~/public_ip

# Continue until the SSH connection is ready
while [ -z ${SSH_READY} ]; do
  echo "Trying to connect..."
  if [ "$(nc.traditional $(aws ec2 describe-instances --filter Name='key-name',Values=\"$PROJECT_NAME\" 'Name=instance-state-name,Values=running' --query 'Reservations[].Instances[].[PublicIpAddress]' --output text) -z -w 4 22; echo $?)" = 0 ]; then
      SSH_READY=true;
  fi
  sleep 1
done

# Poll SSH to get instance ID to ensure that SSH connection can be acquired
while [ -z "${INSTANCE_ID}"]; do
  sleep 1
  INSTANCE_ID=$(ssh -vvv -i ~/$PROJECT_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "curl -s http://169.254.169.254/latest/meta-data/instance-id; echo")
done

echo $INSTANCE_ID -> ~/instance_id

# Update yum repositories
ssh -tt -i ~/$PROJECT_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo su root -c 'yum update -y'"

# Install docker from yum repo
ssh -tt -i ~/$PROJECT_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo su root -c 'yum install -y docker'"

# Start docker
ssh -tt -i ~/$PROJECT_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo su root -c 'sudo service docker start'"

# Add permission for ec2-user to run docker commands
ssh -tt -i ~/$PROJECT_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo usermod -a -G docker ec2-user"

# Check docker is running
ssh -tt -i ~/$PROJECT_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo docker ps"

# Install Docker compose
ssh -tt -i ~/$PROJECT_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo pip install docker-compose"
