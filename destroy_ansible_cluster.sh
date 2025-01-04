#!/bin/bash

# Variables
AWS_REGION="us-east-1"
SECURITY_GROUP_NAME="ansible-cluster-sg"
PEM_KEY_NAME="ansible-controller-key"

# Step 1: Terminate EC2 Instances
echo "Fetching EC2 instance IDs for termination..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-controller,worker-node-amazon-linux,worker-node-ubuntu" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -n "$INSTANCE_IDS" ]; then
  echo "Terminating EC2 instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $AWS_REGION
  echo "Waiting for instances to terminate..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $AWS_REGION
  echo "EC2 instances terminated."
else
  echo "No EC2 instances found to terminate."
fi

# Step 2: Delete Security Group
echo "Fetching Security Group ID for $SECURITY_GROUP_NAME..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null)

if [ -n "$SECURITY_GROUP_ID" ]; then
  echo "Deleting Security Group: $SECURITY_GROUP_ID"
  aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID --region $AWS_REGION
  echo "Security Group deleted."
else
  echo "No Security Group found to delete."
fi

# Step 3: Delete PEM Key
if [ -f "$PEM_KEY_NAME.pem" ]; then
  echo "Removing local PEM key file: $PEM_KEY_NAME.pem"
  rm -f $PEM_KEY_NAME.pem
fi

echo "Deleting Key Pair from AWS..."
aws ec2 delete-key-pair --key-name $PEM_KEY_NAME --region $AWS_REGION
echo "Key Pair deleted."

# Step 4: Clean up local Ansible environment
echo "Cleaning up local Ansible environment..."
rm -f ~/inventory.yml 2>/dev/null
rm -f ~/deploy_website.yml 2>/dev/null
rm -rf ~/ansible/ 2>/dev/null

echo "All resources and local files have been cleaned up."
