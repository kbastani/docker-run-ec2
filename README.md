# Docker Run EC2

A Docker container that manages ephemeral EC2 instances using the AWS CLI with Docker Compose pre-installed. This can be used securely from any build server (such as Travis), without needing to install any command line dependencies of the AWS CLI.

## Usage

This container image is used to manage remote EC2 instances on AWS using the AWS CLI. The purpose of this container is to run Docker as a service on EC2 for ephemeral integration testing of versioned backing services. For example, you can use this container to launch a remote EC2 instance and use Docker Compose on the remote instance to launch a set of backing services you need for integration tests in your build.

### Environment Variables

As parameters to the container, you will need to provide the following environment variables:

* `AWS_ACCESS_KEY_ID`
  * Your AWS API access key id (provided by AWS)
* `AWS_SECRET_ACCESS_KEY`
  * Your AWS API secret access key (provided by AWS)
* `PROJECT_NAME`
  * Choose a unique project name for launching an EC2 instance

Set your environment variables on the host where you will run this Docker container from.

    $ export AWS_ACCESS_KEY_ID=replace
    $ export AWS_SECRET_ACCESS_KEY=replace
    $ export PROJECT_NAME=docker-run-ec2

### Storage Volume Mapping

In order to retrieve the public IP, instance ID, and generated SSH key pair, a container volume must be mapped to your host file system. From the directory that you run the Docker command from, create a directory that will serve as your host volume mapping. Make sure that you always run this command from this directory so that state can be restored each time you run the `docker-run-ec2` container.

For example, for the _docker run_ example to work, you must make sure to create the following directory:

    # Create the volume for persisting container state from AWS CLI
    $ mkdir -p aws-volume

### Docker Run Example

Now you can use the environment variables in your _docker run_ command for the container:

    $ docker run --rm -ti -v $(pwd -P)/aws-volume:/root \
      --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
      --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
      --env PROJECT_NAME=$PROJECT_NAME \
      --name=aws kbastani/docker-run-ec2 \
      sh ./aws-create-instance.sh

After the `aws-create-instance.sh` script completes, you will have access to issue Docker commands to the remote instance. For example, if I wanted to launch a RabbitMQ container on the remote instance:

    $ docker run --rm -ti -v $(pwd -P)/aws-volume:/root \
      --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
      --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
      --env PROJECT_NAME=$PROJECT_NAME \
      --env DOCKER_COMMAND="run -d -p 15672:15672 -p 5671:5671 -p 5672:5672 -p 4369:4369 --name rabbit rabbitmq:3-management" \
      --name=aws kbastani/docker-run-ec2 \
      sh ./ssh-docker-run.sh

Notice the extra environment variable for `ssh-docker-run.sh`, which is named `DOCKER_COMMAND`. Here you have full access to the remote Docker machine, which I've configured to `run -d -p 15672:15672 -p 5671:5671 -p 5672:5672 -p 4369:4369 --name rabbit rabbitmq:3-management`.

Now you will be able to access RabbitMQ's management tool on the remote EC2 instance, only from the host machine.

    $ export PUBLIC_IP="$(cat aws-volume/public_ip | sed 's/\( -\)//1')"
    $ open http://$PUBLIC_IP:15672

### Terminate Instance

Finally, you'll want to make sure to terminate your remote EC2 instance using the following command.

    $ docker run --rm -ti -v $(pwd -P)/aws-volume:/root \
      --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
      --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
      --env PROJECT_NAME=$PROJECT_NAME \
      --name=aws kbastani/docker-run-ec2 \
      sh ./aws-delete-instance.sh

The instance ID that is located in `./aws-volume` will be terminated. It will take a few minutes for the instance to terminate before you can create a new instance with the same key pair name.

# License

This project is licensed under Apache License 2.0.
