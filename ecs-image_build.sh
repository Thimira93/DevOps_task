#!/bin/bash

set -e


if [ -z "$1" ]; then
    echo "Usage: $0 <version-tag>"
    exit 1
fi

VERSION_TAG=$1


# Set environment variables
AWS_REGION='us-east-1'
ECR_REPO_NAME='ecs-demo'
ECR_REPO_URI="989233163663.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
REPO_URL='https://github.com/Thimira93/DevOps_task.git'

# Check if the repo directory exists
if [ -d "repo" ]; then
  echo "Removing existing repository directory..."
  rm -rf repo
fi

# Clone the repository
echo "Cloning repository..."
git clone $REPO_URL repo
cd repo

# Build Docker image
echo "Building Docker image..."
docker build -t ${ECR_REPO_URI}:${VERSION_TAG} .

# Login to AWS ECR
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URI

# Push Docker image to ECR
echo "Pushing Docker image to ECR..."
docker push ${ECR_REPO_URI}:${VERSION_TAG}

echo "Done."

