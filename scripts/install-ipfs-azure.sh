#!/bin/bash

# IPFS Azure Installation Script
# Complete setup script for IPFS on Azure VMs
# FLAG: Created 2025-05-22T10:54:11-04:00

set -e  # Exit on any error

# Configuration
IPFS_VERSION="0.18.1"  # Update this to the latest stable version as needed
IPFS_PATH="/data/ipfs"
AZURE_SHARE_NAME="ipfsdata"
AZURE_STORAGE_ACCOUNT=""  # To be provided by user
AZURE_STORAGE_KEY=""      # To be provided by user

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as correct user
check_user() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root/sudo"
        print_error "Run as a regular user with sudo privileges"
        exit 1
    fi
    print_status "Running as user: $(whoami)"
}

# Function to install dependencies
install_dependencies() {
    print_step "Installing required dependencies..."
    
    sudo apt update
    sudo apt install -y \
        curl \
        wget \
        jq \
        bc \
        cron \
        systemd \
        fuse \
        cifs-utils

    print_status "Dependencies installed successfully"
}

# Function to install IPFS
install_ipfs() {
    print_step "Installing IPFS version ${IPFS_VERSION}..."
    
    if command_exists ipfs; then
        local current_version=$(ipfs --version | cut -d' ' -f3)
        print_warning "IPFS is already installed (version: ${current_version})"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Skipping IPFS installation"
            return 0
        fi
    fi
    
    # Download and install IPFS
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    local arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) print_error "Unsupported architecture: $arch"; exit 1 ;;
    esac
    
    local download_url="https://dist.ipfs.io/go-ipfs/v${IPFS_VERSION}/go-ipfs_v${IPFS_VERSION}_linux-${arch}.tar.gz"
    print_status "Downloading IPFS from: ${download_url}"
    
    wget -q "$download_url" -O ipfs.tar.gz
    tar -xzf ipfs.tar.gz
    
    print_status "Installing IPFS binary..."
    cd go-ipfs
    sudo bash install.sh
    cd ..
    rm -rf "$temp_dir"
    
    print_status "IPFS installed successfully: $(ipfs --version)"
}

# Function to configure IPFS
configure_ipfs() {
    print_step "Configuring IPFS..."
    
    # Create IPFS directory if it doesn't exist
    sudo mkdir -p "$IPFS_PATH"
    sudo chown "$USER:$USER" "$IPFS_PATH"
    
    # Initialize IPFS repository
    export IPFS_PATH="$IPFS_PATH"
    ipfs init --profile server
    
    # Apply optimized configuration
    ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
    ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
    
    # Set resource limits
    ipfs config --json Swarm.ConnMgr.HighWater 100
    ipfs config --json Swarm.ConnMgr.LowWater 50
    
    # Enable file store (for persistence)
    ipfs config --json Experimental.FilestoreEnabled true
    
    print_status "IPFS configured successfully"
}

# Function to setup Azure file share
setup_azure_storage() {
    print_step "Setting up Azure file share..."
    
    if [[ -z "$AZURE_STORAGE_ACCOUNT" || -z "$AZURE_STORAGE_KEY" ]]; then
        print_warning "Azure storage credentials not provided"
        read -p "Do you want to configure Azure storage now? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Skipping Azure storage setup"
            return 0
        fi
        
        read -p "Enter Azure Storage Account name: " AZURE_STORAGE_ACCOUNT
        read -p "Enter Azure Storage Key: " AZURE_STORAGE_KEY
    fi
    
    # Create mount point
    sudo mkdir -p "/mnt/${AZURE_SHARE_NAME}"
    
    # Create credentials file
    local creds_file="/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT}.cred"
    sudo mkdir -p "/etc/smbcredentials"
    
    echo "username=${AZURE_STORAGE_ACCOUNT}" | sudo tee "$creds_file" > /dev/null
    echo "password=${AZURE_STORAGE_KEY}" | sudo tee -a "$creds_file" > /dev/null
    sudo chmod 600 "$creds_file"
    
    # Add entry to fstab
    local fstab_entry="//${AZURE_STORAGE_ACCOUNT}.file.core.windows.net/${AZURE_SHARE_NAME} /mnt/${AZURE_SHARE_NAME} cifs nofail,vers=3.0,credentials=${creds_file},serverino"
    
    if grep -q "${AZURE_SHARE_NAME}" /etc/fstab; then
        print_warning "Azure file share already in fstab"
    else
        echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
        print_status "Added Azure file share to fstab"
    fi
    
    # Mount the share
    sudo mount -a
    
    # Create IPFS directory on the share
    sudo mkdir -p "/mnt/${AZURE_SHARE_NAME}/ipfs"
    sudo chown "$USER:$USER" "/mnt/${AZURE_SHARE_NAME}/ipfs"
    
    # Create symbolic link
    if [[ -L "$IPFS_PATH" ]]; then
        sudo rm "$IPFS_PATH"
    else
        sudo mv "$IPFS_PATH" "${IPFS_PATH}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi
    
    sudo ln -s "/mnt/${AZURE_SHARE_NAME}/ipfs" "$IPFS_PATH"
    sudo chown -h "$USER:$USER" "$IPFS_PATH"
    
    print_status "Azure file share configured successfully"
}

# Function to create systemd service
create_systemd_service() {
    print_step "Creating IPFS systemd service..."
    
    local service_file="/etc/systemd/system/ipfs.service"
    
    cat << EOF | sudo tee "$service_file" > /dev/null
[Unit]
Description=IPFS daemon
After=network.target

[Service]
Type=simple
User=$USER
Environment="IPFS_PATH=$IPFS_PATH"
ExecStart=$(which ipfs) daemon --enable-gc
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable ipfs
    sudo systemctl start ipfs
    
    print_status "IPFS service created and started"
}

# Function to setup bandwidth manager
setup_bandwidth_manager() {
    print_step "Setting up IPFS bandwidth manager..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local bandwidth_script="${script_dir}/ipfs-bandwidth-manager.sh"
    local cron_script="${script_dir}/setup-ipfs-cron.sh"
    
    # Copy bandwidth manager to system location
    sudo cp "$bandwidth_script" /usr/local/bin/ipfs-bandwidth-manager
    sudo chmod +x /usr/local/bin/ipfs-bandwidth-manager
    
    # Run cron setup script
    bash "$cron_script" install
    
    print_status "Bandwidth manager setup completed"
}

# Main function
main() {
    print_step "Starting IPFS Azure installation..."
    
    check_user
    install_dependencies
    install_ipfs
    configure_ipfs
    setup_azure_storage
    create_systemd_service
    setup_bandwidth_manager
    
    print_status "IPFS installation on Azure completed successfully!"
    print_status "IPFS daemon is running as a systemd service"
    print_status "Bandwidth management is configured and active"
    print_status "Check status with: sudo systemctl status ipfs"
    print_status "Check bandwidth with: ipfs-bandwidth-manager status"
}

# Run main function
main "$@"
