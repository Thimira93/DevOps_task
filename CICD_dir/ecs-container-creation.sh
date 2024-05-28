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

# Variables
CLUSTER_NAME="new-ecs-cluster-fg"
SERVICE_NAME="ecs-demo-service-fg"
TASK_FAMILY="New-ecs-demo-tskdefinition-fg"
CONTAINER_NAME="ecs-demo-fg"
IMAGE_URI="${ECR_REPO_URI}:${VERSION_TAG}"

# Replace with your subnet IDs
SUBNET_IDS=("subnet-0c73a48a91489cd6a" "subnet-05f9f6641e7452cb7")
# Replace with your security group ID
SECURITY_GROUP_ID="sg-093fdac65a3c5b8eb"

# Replace with your target group ARN
TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:989233163663:targetgroup/ecs-tg3/03d9c80840f046b9"

# Convert arrays to comma-separated strings for AWS CLI
SUBNET_IDS_CSV=$(IFS=,; echo "${SUBNET_IDS[*]}")

# Get the current task definition JSON
CURRENT_TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY)
echo $CURRENT_TASK_DEFINITION

# Extract the container definitions and modify the image URI
NEW_CONTAINER_DEFINITIONS=$(echo $CURRENT_TASK_DEFINITION | jq --arg IMAGE_URI "$IMAGE_URI" '.taskDefinition.containerDefinitions | .[0].image = $IMAGE_URI')
#NEW_CONTAINER_DEFINITIONS=$(echo $NEW_CONTAINER_DEFINITIONS | jq '[.]')

#NEW_CONTAINER_DEFINITIONS=$(echo $CURRENT_TASK_DEFINITION | jq --arg IMAGE_URI "$IMAGE_URI" '.taskDefinition.containerDefinitions | .[0].image = $IMAGE_URI | [.]')
echo $NEW_CONTAINER_DEFINITIONS

# Register new task definition revision
NEW_TASK_DEFINITION=$(aws ecs register-task-definition \
  --family $TASK_FAMILY \
  --execution-role-arn arn:aws:iam::989233163663:role/ecsTaskExecutionRole \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu "256" \
  --memory "512" \
  --container-definitions "$NEW_CONTAINER_DEFINITIONS")

# Extract new revision number
NEW_REVISION=$(echo $NEW_TASK_DEFINITION | jq .taskDefinition.revision)
echo "Revision: $NEW_REVISION"

# Create or update the service with the new task definition revision
SERVICE_EXISTS=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].status' --output text)

if [ "$SERVICE_EXISTS" == "ACTIVE" ]; then
  echo "Updating the existing service..."
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --task-definition $TASK_FAMILY:$NEW_REVISION \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS_CSV],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=$TARGET_GROUP_ARN,containerName=$CONTAINER_NAME,containerPort=80"
else
  echo "Creating a new service..."
  aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition $TASK_FAMILY:$NEW_REVISION \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS_CSV],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=$TARGET_GROUP_ARN,containerName=$CONTAINER_NAME,containerPort=80"
fi

echo "Service is now running with the new task definition revision: $TASK_FAMILY:$NEW_REVISION"

