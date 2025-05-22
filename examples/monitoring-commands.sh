#!/bin/bash

# IPFS Monitoring Commands
# Useful commands for monitoring IPFS node performance and health
# FLAG: Created 2025-05-22T10:54:11-04:00

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print command and then execute it
run_command() {
    echo -e "${GREEN}$$ $1${NC}"
    eval "$1"
    echo ""
}

# Function to print monitoring tips
print_tip() {
    echo -e "${YELLOW}TIP:${NC} $1\n"
}

# Example 1: Basic IPFS Node Information
print_header "BASIC NODE INFORMATION"

run_command "ipfs id"
print_tip "The 'id' command shows your node's identity, public key, addresses, and supported protocols."

run_command "ipfs version"
print_tip "Always check your IPFS version when troubleshooting."

# Example 2: Network Connectivity
print_header "NETWORK CONNECTIVITY"

run_command "ipfs swarm peers | wc -l"
print_tip "This shows the number of connected peers. A healthy node typically has 10-100 connections."

run_command "ipfs swarm peers | head -5"
print_tip "This shows details about connected peers. Use 'ipfs swarm peers' to see all."

# Example 3: Bandwidth Usage
print_header "BANDWIDTH USAGE"

run_command "ipfs stats bw"
print_tip "Shows total bandwidth usage. This is what the bandwidth manager monitors."

run_command "ipfs stats bw -t 5s -i 1s"
print_tip "Shows real-time bandwidth usage over 5 seconds with 1-second intervals."

# Example 4: Storage Usage
print_header "STORAGE USAGE"

run_command "ipfs repo stat"
print_tip "Shows repository statistics including size, number of objects, and version."

run_command "ipfs repo stat -s"
print_tip "Shows a human-readable summary of repository size."

# Example 5: Content Management
print_header "CONTENT MANAGEMENT"

run_command "ipfs pin ls --type=recursive | wc -l"
print_tip "Shows the number of recursively pinned items (directories and files)."

run_command "ipfs pin ls --type=recursive | head -5"
print_tip "Shows the first few pinned items. These won't be garbage-collected."

# Example 6: DHT (Distributed Hash Table)
print_header "DHT INFORMATION"

run_command "ipfs dht findprovs QmY5heUM5qgRubMDD1og9fhCPA6QdkMp3QCwd4s7gJsyE7 | head -3"
print_tip "Finds providers for a specific CID. This tests DHT functionality."

run_command "ipfs dht findpeer $(ipfs id -f='<id>') 2>&1 || echo 'Expected error: cannot find self'"
print_tip "Tries to find a specific peer. Useful for testing DHT routing."

# Example 7: IPFS Config
print_header "CONFIGURATION"

run_command "ipfs config Addresses"
print_tip "Shows the node's address configuration."

run_command "ipfs config Swarm.ConnMgr"
print_tip "Shows connection manager settings that affect peer connections."

# Example 8: Diagnostic Commands
print_header "DIAGNOSTICS"

run_command "ipfs diag sys"
print_tip "Shows system information useful for diagnostics."

run_command "ipfs stats repo"
print_tip "Shows detailed repository statistics."

# Example 9: Custom Monitoring Script
print_header "CUSTOM MONITORING"

cat << 'EOF' > ipfs-monitor.sh
#!/bin/bash
# Simple IPFS monitoring script

echo "=== IPFS Monitoring Report ==="
echo "Time: $(date)"
echo ""

echo "Node ID: $(ipfs id -f='<id>')"
echo "Version: $(ipfs version -n)"
echo ""

echo "Connected Peers: $(ipfs swarm peers | wc -l)"
echo "Repo Size: $(ipfs repo stat -s | grep RepoSize | awk '{print $2}')"
echo ""

echo "Bandwidth Stats:"
ipfs stats bw
echo ""

echo "System Load:"
uptime
echo ""

echo "Disk Usage:"
df -h | grep -E '(Filesystem|/dev/)'
EOF

chmod +x ipfs-monitor.sh
echo "Created monitoring script: ipfs-monitor.sh"
print_tip "You can run this script periodically or add it to cron for regular monitoring."

# Example 10: Integration with System Monitoring
print_header "SYSTEM INTEGRATION"

echo '
# IPFS Monitoring for Prometheus
# Add to your node_exporter configuration

# IPFS repo size (bytes)
ipfs_repo_size_bytes $(ipfs repo stat -s | grep RepoSize | awk "{print \$2}" | tr -d "B")

# IPFS peer count
ipfs_peer_count $(ipfs swarm peers | wc -l)

# IPFS bandwidth total out (bytes)
ipfs_bandwidth_total_out_bytes $(ipfs stats bw | grep "TotalOut" | awk "{print \$2}" | tr -d ",")

# IPFS bandwidth total in (bytes)
ipfs_bandwidth_total_in_bytes $(ipfs stats bw | grep "TotalIn" | awk "{print \$2}" | tr -d ",")
' > ipfs-prometheus.prom

echo "Created Prometheus metrics example: ipfs-prometheus.prom"
print_tip "This can be used with node_exporter's textfile collector for Prometheus monitoring."

print_header "COMPLETE"
echo "All monitoring examples completed successfully!"
echo "Use these commands regularly to monitor your IPFS node health and performance."
