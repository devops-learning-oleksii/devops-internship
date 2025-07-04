#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if variables.json exists
if [ ! -f "variables.json" ]; then
    print_error "variables.json not found in current directory!"
    exit 1
fi

# Step 1: Run Terraform
print_header "Step 1: Running Terraform"
cd terraform

print_status "Initializing Terraform..."
terraform init

print_status "Applying Terraform changes..."
terraform apply -auto-approve

if [ $? -eq 0 ]; then
    print_status "Terraform completed successfully!"
else
    print_error "Terraform failed!"
    exit 1
fi

cd ..

# Step 2: Run Ansible
print_header "Step 2: Running Ansible"
cd ansible

print_status "Running Ansible playbook..."
ansible-playbook -i inventory.ini playbooks/deploy.yml

if [ $? -eq 0 ]; then
    print_status "Ansible completed successfully!"
else
    print_error "Ansible failed!"
    exit 1
fi

cd ..

