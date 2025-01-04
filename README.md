# Ansible Project for Deploying a Website

## Project Overview
This repository demonstrates the steps to deploy a website using Ansible. 

It includes: 
- Setting up a **controller node**, and **managed nodes**.
- Configuring **keyless SSH access**.
- Writing **playbooks**, **inventories**, and using them.
- **Cleaning up** resources.

---

## Setup Instructions

## Prerequisites
#### 1: Create a Bash shell script to set up the Ansible cluster
```bash
mkdir ansible
cd ansible
nano setup_ansible_cluster.sh
```
- Add the following content:
```bash
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
```
- Make the file executable
```bash
chmod +x setup_ansible_cluster.sh
```
#### 1: Create a Bash Shell script that will help with cleanup
- Create a file and name it destroy_ansible_cluster.sh
```bash
nano destroy_ansible_cluster.sh
```
- Add the following content:
```bash
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
```
- Make the file executable
```bash
chmod +x destroy_ansible_cluster.sh
```

### Step 1: Controller Node (Ubuntu)

**Install Ansible**
```bash
sudo apt-get update
sudo apt install software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt update
sudo apt install ansible
```

**Keyless SSH Access**

- Generate SSH Key on Controller
- Navigate to the .ssh directory and generate a key pair:
```bash
cd ~/.ssh
ssh-keygen
```

- Copy the public key:
```bash
cat id_ed25519.pub
```

### Step 2: Managed Nodes
**Install Python:**
```bash
sudo apt-get update
sudo apt-get install python
```

**Set Up Authorized Keys on Managed Nodes**
- Add the public key to each node:
```bash
sudo nano ~/.ssh/authorized_keys
```
- Paste the public key from the controller node and save.

### Step 3: Create the Website Content
- Create an index.html file and add the content below: 
```bash
mkdir webapp
cd webapp
nano index.html
```

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enroll in Our Program</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            background-color: #f4f4f9;
            margin: 0;
            padding: 0;
        }
        header {
            background-color: #0073e6;
            color: white;
            padding: 10px 0;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        header img {
            height: 50px;
            margin-right: 10px;
        }
        header h1 {
            margin: 0;
            font-size: 24px;
        }
        form {
            max-width: 400px;
            margin: 20px auto;
            padding: 20px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        input, select {
            width: 100%;
            margin: 10px 0;
            padding: 10px;
            font-size: 16px;
            border: 1px solid #ccc;
            border-radius: 4px;
        }
        button {
            background: #0073e6;
            color: white;
            font-size: 16px;
            padding: 10px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        button:hover {
            background: #005bb5;
        }
        .success-message {
            font-size: 18px;
            color: #28a745;
        }
    </style>
</head>
<body>
    <header>
        <h1>Enroll in Our Program</h1>
    </header>

    <form id="enrollmentForm">
        <input type="text" id="firstName" name="firstName" placeholder="First Name" required>
        <input type="text" id="lastName" name="lastName" placeholder="Last Name" required>
        <input type="tel" id="phone" name="phone" placeholder="Phone Number" required>
        <input type="email" id="email" name="email" placeholder="Email Address" required>
        <select id="course" name="course" required>
            <option value="" disabled selected>Select a Course</option>
            <option value="DevOps">DevOps</option>
            <option value="Cloud">Cloud</option>
        </select>
        <button type="submit">Submit</button>
    </form>

    <div id="successMessage" class="success-message" style="display: none;">
        Thank you for enrolling! Your data has been successfully submitted.
    </div>

    <script>
        const form = document.getElementById('enrollmentForm');
        const successMessage = document.getElementById('successMessage');

        form.addEventListener('submit', async (event) => {
            event.preventDefault(); // Prevent page reload

            const data = {
                firstName: document.getElementById('firstName').value,
                lastName: document.getElementById('lastName').value,
                phone: document.getElementById('phone').value,
                email: document.getElementById('email').value,
                course: document.getElementById('course').value
            };

            try {
                const response = await fetch('https://72su899n2k.execute-api.us-east-1.amazonaws.com/dev/enroll', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data),
                });

                if (response.ok) {
                    successMessage.style.display = 'block';
                    form.reset();
                } else {
                    alert('Error submitting the form. Please try again.');
                }
            } catch (error) {
                alert('Unable to submit form. Please check your connection and try again.');
            }
        });
    </script>
</body>
</html>
```


### Step 4: Configure Ansible Inventory
**Add the Nodes to the Hosts file on the Controller Node:**
```bash
sudo nano /etc/ansible/hosts
```
- Add the following content:
```ini
[webservers]
node1 ansible_host=<Public_IP_Address> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

**Create an Inventory File**
```bash
nano inventory.yml
```
- Add the following content:
```ini
all:
  hosts:
    worker-node1:
      ansible_host: <IP-Address/Hostname-Ubuntu>
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

    worker-node1:
      ansible_host: <IP-Address/Hostname-AmazonLinux>
      ansible_user: ec2-user
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

    worker-node1:
      ansible_host: <IP-Address/Hostname-AmazonLinux>
      ansible_user: ec2-user
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
```

**Test Connection:**
```bash
ansible -m ping webservers
```

**Deploy Website**

- Create a playbook to deploy the website and name it ***deploy_website.yml***
```yaml
---
- name: Deploy T2S Website
  hosts: all
  become: yes
  tasks:
    - name: Install Python on Debian-based systems
      raw: |
        sudo apt update && sudo apt install -y python3 python3-apt
      when: ansible_facts['os_family'] == 'Debian'
      changed_when: false

    - name: Install Python on Red Hat-based systems
      raw: |
        sudo yum update -y && sudo yum install -y python3
      when: ansible_facts['os_family'] == 'RedHat'
      changed_when: false

    - name: Install Nginx
      package:
        name: nginx
        state: present
        update_cache: yes

    - name: Start and enable Nginx
      service:
        name: nginx
        state: started
        enabled: yes

    - name: Copy website files
      copy:
        src: webapp/index.html
        dest: "{{ '/var/www/html/index.html' if ansible_facts['os_family'] == 'Debian' else '/usr/share/nginx/html/index.html' }}"
        owner: root
        group: root
        mode: '0644'

    - name: Adjust permissions on web server files
      file:
        path: "{{ '/var/www/html' if ansible_facts['os_family'] == 'Debian' else '/usr/share/nginx/html' }}"
        owner: "{{ 'www-data' if ansible_facts['os_family'] == 'Debian' else 'nginx' }}"
        group: "{{ 'www-data' if ansible_facts['os_family'] == 'Debian' else 'nginx' }}"
        recurse: yes
```

**Run the Playbook**
- Execute the playbook:
```bash
ansible-playbook -i inventory.yml deploy_website.yml
```

---

## Clean Up Resources
### 1.	Terminate EC2 Instances:
```bash
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId, PublicIpAddress, Tags[?Key==`Name`].Value | [0]]' --output table
aws ec2 terminate-instances --instance-ids <INSTANCE_IDs>
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,State.Name]" --output table
```

### 2.	Delete Security Group:
```bash
aws ec2 describe-security-groups --filters "Name=group-name,Values=ansible-sg" --query "SecurityGroups[*].GroupId" --output text
aws ec2 delete-security-group --group-id <SECURITY_GROUP_ID>
```

### 3.	Remove PEM Key:
```
aws ec2 delete-key-pair --key-name ansible-key
rm -f ~/.ssh/ansible-key.pem
```

### 4.	Clean Local Environment:
```bash
rm -f ~/inventory.yml
rm -f ~/deploy_website.yml
rm -rf ~/ansible/
```
---
