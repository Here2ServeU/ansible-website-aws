#!/bin/bash

# Variables
AWS_REGION="us-east-1"
SECURITY_GROUP_NAME="ansible-cluster-sg"
PEM_KEY_NAME="ansible-controller-key"
CONTROLLER_NAME="ansible-controller"
WORKER1_NAME="worker-node-amazon-linux"
WORKER2_NAME="worker-node-ubuntu"
CONTROLLER_AMI="ami-0e2c8caa4b6378d8c" # Replace with Ubuntu AMI
WORKER1_AMI="ami-01816d07b1128cd2d"   # Replace with Amazon Linux AMI
WORKER2_AMI="ami-0e2c8caa4b6378d8c"   # Replace with Ubuntu AMI
INSTANCE_TYPE="t2.micro"

# Step 1: Create Security Group
echo "Creating Security Group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name $SECURITY_GROUP_NAME \
  --description "Security group for Ansible cluster" \
  --region $AWS_REGION \
  --query "GroupId" --output text)

echo "Security Group ID: $SECURITY_GROUP_ID"

# Add rules to Security Group
echo "Adding rules to Security Group..."
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION

aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION

# Step 2: Create PEM Key Pair for Controller Node
echo "Creating PEM Key Pair..."
aws ec2 create-key-pair \
  --key-name $PEM_KEY_NAME \
  --query "KeyMaterial" \
  --output text > $PEM_KEY_NAME.pem
chmod 400 $PEM_KEY_NAME.pem
echo "PEM Key Pair created and saved as $PEM_KEY_NAME.pem"

# Step 3: Launch Controller Node
echo "Launching Controller Node..."
CONTROLLER_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $CONTROLLER_AMI \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $PEM_KEY_NAME \
  --security-group-ids $SECURITY_GROUP_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$CONTROLLER_NAME}]" \
  --region $AWS_REGION \
  --query "Instances[0].InstanceId" --output text)
echo "Controller Node Instance ID: $CONTROLLER_INSTANCE_ID"

# Step 4: Launch Worker Nodes
echo "Launching Worker Node 1 (Amazon Linux)..."
WORKER1_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $WORKER1_AMI \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $PEM_KEY_NAME \
  --security-group-ids $SECURITY_GROUP_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$WORKER1_NAME}]" \
  --region $AWS_REGION \
  --query "Instances[0].InstanceId" --output text)
echo "Worker Node 1 Instance ID: $WORKER1_INSTANCE_ID"

echo "Launching Worker Node 2 (Ubuntu)..."
WORKER2_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $WORKER2_AMI \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $PEM_KEY_NAME \
  --security-group-ids $SECURITY_GROUP_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$WORKER2_NAME}]" \
  --region $AWS_REGION \
  --query "Instances[0].InstanceId" --output text)
echo "Worker Node 2 Instance ID: $WORKER2_INSTANCE_ID"

# Step 5: Display Public IP Addresses
echo "Fetching Public IP Addresses..."
INSTANCE_PUBLIC_IPS=$(aws ec2 describe-instances \
  --instance-ids $CONTROLLER_INSTANCE_ID $WORKER1_INSTANCE_ID $WORKER2_INSTANCE_ID \
  --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value,PublicIpAddress]" \
  --output table)
echo "$INSTANCE_PUBLIC_IPS"

echo "Ansible cluster setup is complete!"
