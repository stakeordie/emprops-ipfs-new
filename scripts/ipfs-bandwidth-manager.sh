#!/bin/bash

# IPFS Bandwidth Manager for Kubo 0.35.0
# Manages bandwidth limits for IPFS node participation

# Configuration
DAILY_LIMIT_GB=10
MONTHLY_LIMIT_GB=250
STATS_FILE="/var/log/ipfs-bandwidth-stats.json"
CONFIG_FILE="/etc/ipfs-bandwidth-config"
LOG_FILE="/var/log/ipfs-bandwidth.log"

# Ensure log directory exists
sudo mkdir -p /var/log 2>/dev/null || true
sudo touch $STATS_FILE $CONFIG_FILE $LOG_FILE 2>/dev/null || true
sudo chown $USER:$USER $STATS_FILE $CONFIG_FILE $LOG_FILE 2>/dev/null || true

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a $LOG_FILE
}

# Function to get current IPFS bandwidth stats
get_ipfs_stats() {
    local stats
    stats=$(ipfs stats bw 2>/dev/null) || { echo "0"; return; }
    
    # Parse TotalOut from stats
    local total_out
    total_out=$(echo "$stats" | grep "TotalOut" | awk '{print $2}' | tr -d ',')
    
    # If that failed, try alternative parsing
    if [[ -z "$total_out" ]]; then
        total_out=$(echo "$stats" | grep -oE 'TotalOut[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | head -1)
    fi
    
    echo "${total_out:-0}"
}

# Function to convert bytes to GB
bytes_to_gb() {
    local bytes=${1:-0}
    if [[ "$bytes" =~ ^[0-9]+$ ]] && [[ "$bytes" -gt 0 ]]; then
        echo "scale=3; $bytes / 1073741824" | bc -l 2>/dev/null || echo "0.000"
    else
        echo "0.000"
    fi
}

# Function to get current date info
get_date_info() {
    local current_date=$(date '+%Y-%m-%d')
    local current_month=$(date '+%Y-%m')
    echo "$current_date|$current_month"
}

# Function to load/save stats
load_stats() {
    if [[ -f $STATS_FILE ]]; then
        cat $STATS_FILE 2>/dev/null || echo '{"daily_usage":0,"monthly_usage":0,"last_date":"","last_month":"","last_total_out":0,"mode":"full"}'
    else
        echo '{"daily_usage":0,"monthly_usage":0,"last_date":"","last_month":"","last_total_out":0,"mode":"full"}'
    fi
}

save_stats() {
    echo "$1" > $STATS_FILE 2>/dev/null || true
}

# Function to switch to restricted mode (own content only)
enable_restricted_mode() {
    log_message "Switching to RESTRICTED mode - serving own content only"
    
    # Reduce connections dramatically to limit network participation
    ipfs config --json Swarm.ConnMgr.HighWater 5 2>/dev/null || log_message "Warning: Could not set HighWater"
    ipfs config --json Swarm.ConnMgr.LowWater 2 2>/dev/null || log_message "Warning: Could not set LowWater"
    
    # Reduce DHT participation (use dhtclient instead of dht)
    ipfs config Routing.Type dhtclient 2>/dev/null || log_message "Warning: Could not set routing to dhtclient"
    
    # Reduce reprovider frequency
    ipfs config --json Reprovider.Interval '"24h"' 2>/dev/null || log_message "Warning: Could not set reprovider interval"
    
    # Restart IPFS to apply changes
    sudo systemctl restart ipfs
    sleep 5  # Give IPFS time to restart
    
    echo "restricted" > $CONFIG_FILE
    log_message "IPFS switched to restricted mode successfully"
}

# Function to switch to full participation mode
enable_full_mode() {
    log_message "Switching to FULL PARTICIPATION mode"
    
    # Normal connection limits
    ipfs config --json Swarm.ConnMgr.HighWater 100 2>/dev/null || log_message "Warning: Could not set HighWater"
    ipfs config --json Swarm.ConnMgr.LowWater 50 2>/dev/null || log_message "Warning: Could not set LowWater"
    
    # Full DHT participation
    ipfs config Routing.Type dht 2>/dev/null || log_message "Warning: Could not set routing to dht"
    
    # Normal reprovider frequency
    ipfs config --json Reprovider.Interval '"12h"' 2>/dev/null || log_message "Warning: Could not set reprovider interval"
    
    # Restart IPFS to apply changes
    sudo systemctl restart ipfs
    sleep 5  # Give IPFS time to restart
    
    echo "full" > $CONFIG_FILE
    log_message "IPFS switched to full participation mode successfully"
}

# Function to compare GB values (handles decimal comparisons)
compare_gb() {
    local value1=$1
    local value2=$2
    # Use bc for decimal comparison, return 1 if value1 >= value2, 0 otherwise
    local result=$(echo "$value1 >= $value2" | bc -l 2>/dev/null)
    echo "${result:-0}"
}

# Main bandwidth checking logic
check_bandwidth() {
    local date_info=$(get_date_info)
    local current_date=$(echo $date_info | cut -d'|' -f1)
    local current_month=$(echo $date_info | cut -d'|' -f2)
    
    # Get current IPFS stats
    local current_total_out=$(get_ipfs_stats)
    
    # Load previous stats
    local stats_json=$(load_stats)
    local last_date=$(echo "$stats_json" | jq -r '.last_date // ""' 2>/dev/null || echo "")
    local last_month=$(echo "$stats_json" | jq -r '.last_month // ""' 2>/dev/null || echo "")
    local last_total_out=$(echo "$stats_json" | jq -r '.last_total_out // 0' 2>/dev/null || echo "0")
    local daily_usage=$(echo "$stats_json" | jq -r '.daily_usage // 0' 2>/dev/null || echo "0")
    local monthly_usage=$(echo "$stats_json" | jq -r '.monthly_usage // 0' 2>/dev/null || echo "0")
    local current_mode=$(echo "$stats_json" | jq -r '.mode // "full"' 2>/dev/null || echo "full")
    
    # Calculate usage since last check
    local usage_delta=$((current_total_out - last_total_out))
    if [[ $usage_delta -lt 0 ]]; then
        usage_delta=0  # Handle IPFS restart or counter reset
    fi
    
    # Reset daily counter if new day
    if [[ "$current_date" != "$last_date" ]]; then
        log_message "New day detected, resetting daily counter"
        daily_usage=0
        
        # If new day and we were restricted due to daily limit, try to enable full mode
        if [[ "$current_mode" == "daily_restricted" ]]; then
            current_mode="full"
            enable_full_mode
        fi
    fi
    
    # Reset monthly counter if new month
    if [[ "$current_month" != "$last_month" ]]; then
        log_message "New month detected, resetting monthly counter"
        monthly_usage=0
        
        # If new month and we were restricted due to monthly limit, try to enable full mode
        if [[ "$current_mode" == "monthly_restricted" ]]; then
            current_mode="full"
            enable_full_mode
        fi
    fi
    
    # Add current usage to counters
    daily_usage=$((daily_usage + usage_delta))
    monthly_usage=$((monthly_usage + usage_delta))
    
    # Convert to GB for comparison
    local daily_gb=$(bytes_to_gb $daily_usage)
    local monthly_gb=$(bytes_to_gb $monthly_usage)
    
    log_message "Daily usage: ${daily_gb}GB / ${DAILY_LIMIT_GB}GB, Monthly usage: ${monthly_gb}GB / ${MONTHLY_LIMIT_GB}GB"
    
    # Check limits and switch modes
    local new_mode="full"
    
    # Check daily limit first (higher priority)
    if [[ "$(compare_gb "$daily_gb" "$DAILY_LIMIT_GB")" == "1" ]]; then
        if [[ "$current_mode" != "daily_restricted" ]]; then
            log_message "Daily limit exceeded (${daily_gb}GB >= ${DAILY_LIMIT_GB}GB)"
            enable_restricted_mode
            new_mode="daily_restricted"
        else
            new_mode="daily_restricted"
        fi
    # Check monthly limit
    elif [[ "$(compare_gb "$monthly_gb" "$MONTHLY_LIMIT_GB")" == "1" ]]; then
        if [[ "$current_mode" != "monthly_restricted" ]]; then
            log_message "Monthly limit exceeded (${monthly_gb}GB >= ${MONTHLY_LIMIT_GB}GB)"
            enable_restricted_mode
            new_mode="monthly_restricted"
        else
            new_mode="monthly_restricted"
        fi
    # If under both limits and currently restricted, enable full mode
    elif [[ "$current_mode" == "daily_restricted" || "$current_mode" == "monthly_restricted" ]]; then
        log_message "Usage under limits, enabling full participation"
        enable_full_mode
        new_mode="full"
    fi
    
    # Save updated stats
    local new_stats
    new_stats=$(echo '{}' | jq \
        --arg daily "$daily_usage" \
        --arg monthly "$monthly_usage" \
        --arg date "$current_date" \
        --arg month "$current_month" \
        --arg total "$current_total_out" \
        --arg mode "$new_mode" \
        '.daily_usage = ($daily | tonumber) | .monthly_usage = ($monthly | tonumber) | .last_date = $date | .last_month = $month | .last_total_out = ($total | tonumber) | .mode = $mode' 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        save_stats "$new_stats"
    else
        log_message "Error: Could not save stats with jq"
    fi
}

# Command line interface
case "$1" in
    "check")
        check_bandwidth
        ;;
    "status")
        stats_json=$(load_stats)
        daily_usage=$(echo "$stats_json" | jq -r '.daily_usage // 0' 2>/dev/null || echo "0")
        monthly_usage=$(echo "$stats_json" | jq -r '.monthly_usage // 0' 2>/dev/null || echo "0")
        mode=$(echo "$stats_json" | jq -r '.mode // "unknown"' 2>/dev/null || echo "unknown")
        daily_gb=$(bytes_to_gb $daily_usage)
        monthly_gb=$(bytes_to_gb $monthly_usage)
        
        echo "=== IPFS Bandwidth Status ==="
        echo "Current mode: $mode"
        echo "Daily usage: ${daily_gb}GB / ${DAILY_LIMIT_GB}GB"
        echo "Monthly usage: ${monthly_gb}GB / ${MONTHLY_LIMIT_GB}GB"
        echo "Config file: $(cat $CONFIG_FILE 2>/dev/null || echo 'not set')"
        echo "Current IPFS total out: $(get_ipfs_stats) bytes"
        ;;
    "reset")
        echo '{"daily_usage":0,"monthly_usage":0,"last_date":"","last_month":"","last_total_out":0,"mode":"full"}' > $STATS_FILE
        enable_full_mode
        log_message "Bandwidth stats reset and full mode enabled"
        ;;
    "force-restricted")
        enable_restricted_mode
        ;;
    "force-full")
        enable_full_mode
        ;;
    *)
        echo "Usage: $0 {check|status|reset|force-restricted|force-full}"
        echo ""
        echo "Commands:"
        echo "  check           - Check current usage and apply restrictions if needed"
        echo "  status          - Show current bandwidth usage and mode"
        echo "  reset           - Reset all counters and enable full mode"
        echo "  force-restricted - Force restricted mode (own content only)"
        echo "  force-full      - Force full participation mode"
        exit 1
        ;;
esac