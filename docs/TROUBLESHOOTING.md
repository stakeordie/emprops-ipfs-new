# IPFS Troubleshooting Guide

This document provides solutions for common issues you might encounter with your IPFS node and bandwidth management system.

## Diagnostic Process (edebugproc)

Following the EmProps error handling philosophy (edebugproc):

1. **Explain**: Understand the error through logs and diagnostics
2. **Debug**: Identify the root cause
3. **Propose**: Determine a solution
4. **Resolve**: Apply the fix
5. **Observe**: Confirm the issue is resolved
6. **Document**: Record the issue and solution

## Common Issues

### IPFS Daemon Won't Start

**Symptoms:**
- `systemctl status ipfs` shows failed status
- Error messages in journalctl

**Potential Causes and Solutions:**

1. **Permission Issues**
   ```bash
   # Check ownership of IPFS directory
   ls -la /data/ipfs
   
   # Fix permissions
   sudo chown -R azureuser:azureuser /data/ipfs
   ```

2. **Port Conflicts**
   ```bash
   # Check if ports are in use
   sudo netstat -tulpn | grep -E '4001|5001|8080'
   
   # Modify IPFS config if needed
   ipfs config Addresses.API /ip4/0.0.0.0/tcp/5002  # Change port
   ```

3. **Corrupted Repository**
   ```bash
   # Backup and reset repository
   cp -r /data/ipfs /data/ipfs_backup
   rm -rf /data/ipfs/*
   export IPFS_PATH=/data/ipfs
   ipfs init --profile server
   ```

### Bandwidth Manager Not Working

**Symptoms:**
- Bandwidth limits not being enforced
- Status command shows incorrect information

**Potential Causes and Solutions:**

1. **Script Permissions**
   ```bash
   # Check permissions
   ls -la /usr/local/bin/ipfs-bandwidth-manager
   
   # Fix permissions
   sudo chmod +x /usr/local/bin/ipfs-bandwidth-manager
   ```

2. **Cron Job Issues**
   ```bash
   # Check if cron jobs are installed
   crontab -l | grep ipfs
   
   # Reinstall cron jobs
   ./scripts/setup-ipfs-cron.sh install
   ```

3. **IPFS Stats Access**
   ```bash
   # Test IPFS stats access
   ipfs stats bw
   
   # If failing, check IPFS daemon status
   sudo systemctl restart ipfs
   ```

4. **Corrupted Stats File**
   ```bash
   # Reset stats file
   ipfs-bandwidth-manager reset
   ```

### Azure Storage Issues

**Symptoms:**
- IPFS data not persisting after restarts
- Mount errors in system logs

**Potential Causes and Solutions:**

1. **Connection Issues**
   ```bash
   # Check if mount is active
   df -h | grep ipfsdata
   
   # Remount if needed
   sudo mount -a
   ```

2. **Credential Problems**
   ```bash
   # Check credential file
   sudo cat /etc/smbcredentials/*.cred
   
   # Update credentials if needed
   # Edit the file with correct credentials
   sudo chmod 600 /etc/smbcredentials/*.cred
   ```

3. **Network Issues**
   ```bash
   # Test network connectivity
   ping STORAGE_ACCOUNT_NAME.file.core.windows.net
   
   # Check Azure service status if unreachable
   ```

### Performance Issues

**Symptoms:**
- Slow IPFS operations
- High CPU or memory usage

**Potential Causes and Solutions:**

1. **Too Many Connections**
   ```bash
   # Check current connections
   ipfs swarm peers | wc -l
   
   # Reduce connection limits
   ipfs config --json Swarm.ConnMgr.HighWater 50
   ipfs config --json Swarm.ConnMgr.LowWater 10
   sudo systemctl restart ipfs
   ```

2. **Garbage Collection Needed**
   ```bash
   # Run manual garbage collection
   ipfs repo gc
   ```

3. **Insufficient Resources**
   ```bash
   # Check resource usage
   top
   
   # Consider upgrading VM size in Azure
   ```

## Log Files to Check

When troubleshooting, check these log files:

- IPFS daemon logs: `journalctl -u ipfs`
- Bandwidth manager logs: `/var/log/ipfs-bandwidth.log`
- Daily reports: `/var/log/ipfs-daily-report.log`
- System logs: `journalctl -xe`

## Getting Help

If you can't resolve the issue using this guide:

1. Check the [IPFS GitHub repository](https://github.com/ipfs/kubo/issues)
2. Ask in the [IPFS forum](https://discuss.ipfs.io/)
3. Contact EmProps support team

<!-- FLAG: Created 2025-05-22T10:54:11-04:00 -->
