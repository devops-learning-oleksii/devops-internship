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

# Check if running on Ubuntu/Debian
if [ ! -f /etc/debian_version ]; then
    print_error "This script is designed for Ubuntu/Debian systems only."
    exit 1
fi

print_header "🚀 Setting up DevOps Environment"

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
sudo apt install -y curl wget unzip gnupg lsb-release software-properties-common

# Install Python and pip
print_status "Installing Python and pip..."
sudo apt install -y python3 python3-pip python3-venv

# Install Terraform
print_status "Installing Terraform..."
if ! command -v terraform &> /dev/null; then
    # Add HashiCorp GPG key
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    
    # Add HashiCorp repository
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    
    # Update and install Terraform
    sudo apt update
    sudo apt install -y terraform
    
    print_status "Terraform installed successfully!"
else
    print_status "Terraform is already installed: $(terraform version | head -n1)"
fi



# Create Python virtual environment
print_status "Creating Python virtual environment..."
VENV_PATH="./ansible/venv"

# Create the directory structure if it doesn't exist
mkdir -p "$(dirname "$VENV_PATH")"

# Create virtual environment
if [ ! -d "$VENV_PATH" ]; then
    python3 -m venv "$VENV_PATH"
    print_status "Virtual environment created at $VENV_PATH"
else
    print_status "Virtual environment already exists at $VENV_PATH"
fi

# Activate virtual environment and install Ansible
print_status "Installing Ansible and dependencies..."
source "$VENV_PATH/bin/activate"

# Upgrade pip
pip install --upgrade pip

# Install Ansible and collections
pip install ansible boto3 botocore

# Install Ansible collections
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install community.general

print_status "Ansible installed successfully!"

# Install additional useful tools
print_status "Installing additional tools..."
sudo apt install -y git tree

# Create SSH directory if it doesn't exist
print_status "Setting up SSH directory..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Create a basic SSH config file if it doesn't exist
if [ ! -f ~/.ssh/config ]; then
    touch ~/.ssh/config
    chmod 600 ~/.ssh/config
    print_status "Created ~/.ssh/config file"
fi

# Deactivate virtual environment
deactivate

print_header "✅ Environment Setup Complete!"
echo ""
print_status "Summary of installed components:"
echo "  - Terraform: $(terraform version | head -n1)"
echo "  - Python: $(python3 --version)"
echo "  - Virtual Environment: $VENV_PATH"
echo ""
print_status "Next steps:"
echo "  1. Activate Python venv: source ./ansible/venv/bin/activate"
echo "  2. Verify Ansible: ansible --version"
echo "  3. Place your SSH key in ~/.ssh/"
echo "  4. Run ./deploy.sh to deploy infrastructure"
echo ""
print_warning "Remember to configure your AWS credentials before running Terraform!"
print_status "Setup completed successfully! 🎉"
