# IPFS Setup Guide for Azure

This document provides step-by-step instructions for setting up an IPFS node on an Azure VM with bandwidth management.

## Prerequisites

- Azure VM (Ubuntu 20.04 LTS or newer recommended)
- User with sudo privileges
- Azure Storage Account (for persistent storage)

## Quick Setup

For a complete automated setup, use the installation script:

```bash
./scripts/install-ipfs-azure.sh
```

This script will:
1. Install IPFS and dependencies
2. Configure IPFS with optimized settings
3. Set up Azure file share for persistent storage
4. Create a systemd service for IPFS
5. Configure bandwidth management

## Manual Setup Process

If you prefer a manual setup or need to customize specific components, follow these steps:

### 1. Install IPFS

```bash
# Download IPFS
wget https://dist.ipfs.io/go-ipfs/v0.18.1/go-ipfs_v0.18.1_linux-amd64.tar.gz
tar -xzf go-ipfs_v0.18.1_linux-amd64.tar.gz
cd go-ipfs

# Install IPFS
sudo bash install.sh
ipfs --version  # Verify installation
```

### 2. Initialize IPFS

```bash
# Create data directory
sudo mkdir -p /data/ipfs
sudo chown $USER:$USER /data/ipfs

# Initialize IPFS
export IPFS_PATH=/data/ipfs
ipfs init --profile server
```

### 3. Configure IPFS

```bash
# Apply optimized configuration
ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
ipfs config --json Swarm.ConnMgr.HighWater 100
ipfs config --json Swarm.ConnMgr.LowWater 50
ipfs config --json Experimental.FilestoreEnabled true
```

### 4. Set Up Azure File Share

Follow the commands in `configs/azure-mount-commands.txt` to set up persistent storage.

### 5. Create Systemd Service

```bash
# Copy the service file
sudo cp configs/systemd-service.txt /etc/systemd/system/ipfs.service

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable ipfs
sudo systemctl start ipfs
```

### 6. Set Up Bandwidth Management

```bash
# Copy bandwidth manager script
sudo cp scripts/ipfs-bandwidth-manager.sh /usr/local/bin/ipfs-bandwidth-manager
sudo chmod +x /usr/local/bin/ipfs-bandwidth-manager

# Set up cron jobs
./scripts/setup-ipfs-cron.sh install
```

## Verification

Verify that IPFS is running correctly:

```bash
# Check IPFS service status
sudo systemctl status ipfs

# Check IPFS is responding
ipfs id

# Check bandwidth management status
ipfs-bandwidth-manager status
```

## Next Steps

After setup is complete:

1. Review the [Bandwidth Management](BANDWIDTH-MANAGEMENT.md) documentation
2. Check [Troubleshooting](TROUBLESHOOTING.md) if you encounter any issues
3. Consider [Cost Estimation](COST-ESTIMATION.md) for Azure resource planning

<!-- FLAG: Created 2025-05-22T10:54:11-04:00 -->
