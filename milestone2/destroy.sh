#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if variables.json exists
if [ ! -f "variables.json" ]; then
    print_error "variables.json not found in current directory!"
    exit 1
fi

read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    print_status "Destruction cancelled."
    exit 0
fi

# Destroy infrastructure
print_header "Destroying Infrastructure"
cd terraform

print_status "Destroying infrastructure..."
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    print_status "Infrastructure destroyed successfully!"
else
    print_error "Terraform destroy failed!"
    exit 1
fi

cd ..

print_header "🗑️  Infrastructure destruction completed!"
echo "All AWS resources have been removed."
