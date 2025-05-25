#!/bin/bash

# IPFS Data Migration Script for Azure Setup
# Migrates content from external sources to your Azure IPFS node
# Integrates with bandwidth management and Azure File storage

set -e

# Configuration
LOG_FILE="/var/log/ipfs-migration.log"
HASH_LIST_FILE="ipfs_hashes.txt"  # File containing list of IPFS hashes to migrate
CONCURRENT_DOWNLOADS=1  # Conservative for bandwidth management
RETRY_ATTEMPTS=3
BANDWIDTH_MANAGER="/usr/local/bin/ipfs-bandwidth-manager"
AZURE_STORAGE_PATH="/mnt/ipfs-storage/ipfs"
MAX_SIZE_GB=50  # Skip files larger than this (configurable)
MISSED_FILE="docs/missed.txt"  # 2025-05-24: Added to track missed hashes - AI

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check bandwidth status before migration
check_bandwidth_status() {
    if [[ -x "$BANDWIDTH_MANAGER" ]]; then
        print_step "Checking bandwidth status..."
        local status_output=$($BANDWIDTH_MANAGER status)
        echo "$status_output" | tee -a "$LOG_FILE"
        
        # Check if we're in restricted mode
        # if echo "$status_output" | grep -q "restricted"; then
        #     print_warning "Currently in bandwidth restricted mode"
        #     read -p "Continue with migration anyway? (y/N): " -n 1 -r
        #     echo ""
        #     if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        #         print_status "Migration cancelled due to bandwidth restrictions"
        #         exit 0
        #     fi
        # fi
    else
        print_warning "Bandwidth manager not found at $BANDWIDTH_MANAGER"
    fi
}

# Function to check Azure storage space
check_azure_storage() {
    print_step "Checking Azure storage space..."
    
    if [[ -d "$AZURE_STORAGE_PATH" ]]; then
        local storage_info=$(df -h "$AZURE_STORAGE_PATH" | tail -1)
        local available=$(echo "$storage_info" | awk '{print $4}')
        local used_percent=$(echo "$storage_info" | awk '{print $5}' | tr -d '%')
        
        print_status "Azure storage status:"
        print_status "  Available space: $available"
        print_status "  Used: $used_percent%"
        
        if [[ $used_percent -gt 90 ]]; then
            print_warning "Azure storage is over 90% full!"
            read -p "Continue with migration? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Migration cancelled due to storage space"
                exit 1
            fi
        fi
    else
        print_warning "Azure storage path not found: $AZURE_STORAGE_PATH"
    fi
}

# Function to check if IPFS is running
check_ipfs() {
    if ! ipfs id >/dev/null 2>&1; then
        print_error "IPFS daemon is not running"
        print_error "Try: sudo systemctl start ipfs"
        exit 1
    fi
    print_status "IPFS daemon is running"
    
    # Check if we can access the Azure storage
    if [[ ! -d "$AZURE_STORAGE_PATH" ]]; then
        print_error "Azure storage not mounted at $AZURE_STORAGE_PATH"
        print_error "Try: sudo mount -a"
        exit 1
    fi
    
    print_status "Azure storage accessible"
}

# Enhanced storage estimation with size limits
estimate_storage() {
    local hash=$1
    print_step "Estimating storage for $hash..."
    
    # Get object stats with timeout
    local size_info
    if timeout 30s ipfs dag stat "$hash" 2>/dev/null; then
        size_info=$(timeout 30s ipfs dag stat "$hash" 2>/dev/null)
        
        # Extract size if available
        local size_bytes=$(echo "$size_info" | grep -i "size" | awk '{print $2}' | head -1)
        if [[ -n "$size_bytes" && "$size_bytes" -gt 0 ]]; then
            local size_gb=$(echo "scale=2; $size_bytes / 1024 / 1024 / 1024" | bc -l)
            print_status "Estimated size: ${size_gb}GB"
            
            # Check if size exceeds limit
            if (( $(echo "$size_gb > $MAX_SIZE_GB" | bc -l) )); then
                print_warning "Content size (${size_gb}GB) exceeds limit (${MAX_SIZE_GB}GB)"
                read -p "Continue anyway? (y/N): " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    print_status "Skipping large content"
                    return 1
                fi
            fi
        fi
    else
        print_warning "Could not estimate size for $hash (timeout or unavailable)"
        read -p "Continue without size estimate? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    echo "$size_info" | tee -a "$LOG_FILE"
    
    # Check current repo usage
    local repo_stats=$(ipfs repo stat)
    echo "Current repo status:" | tee -a "$LOG_FILE"
    echo "$repo_stats" | tee -a "$LOG_FILE"
    
    return 0
}

# Enhanced migration function with better error handling
migrate_hash() {
    local hash=$1
    local attempt=1
    
    print_step "Migrating $hash (attempt $attempt/$RETRY_ATTEMPTS)"
    
    # Check if already pinned
    if ipfs pin ls --type=recursive 2>/dev/null | grep -q "^$hash"; then
        print_status "✓ $hash is already pinned, skipping"
        return 0
    fi
    
    while [ $attempt -le $RETRY_ATTEMPTS ]; do
        print_status "Attempt $attempt: Downloading and pinning $hash..."
        
        # Use timeout to prevent hanging (30 seconds max)
        # 2025-05-24: Changed from 300s to 30s to prevent script from getting stuck - AI
        if timeout 30s ipfs pin add "$hash" 2>&1 | tee -a "$LOG_FILE"; then
            print_status "✓ Successfully migrated and pinned $hash"
            
            # Verify the pin with a more robust check
            sleep 2  # Brief pause for pin to register
            
            if ipfs pin ls --type=recursive 2>/dev/null | grep -q "^$hash"; then
                print_status "✓ Pin verified for $hash"
                
                # Check if content is accessible
                if timeout 10s ipfs cat "$hash" >/dev/null 2>&1; then
                    print_status "✓ Content accessibility verified for $hash"
                else
                    print_warning "Content pinned but not immediately accessible for $hash"
                fi
                
                # Update bandwidth manager if available
                if [[ -x "$BANDWIDTH_MANAGER" ]]; then
                    $BANDWIDTH_MANAGER check >/dev/null 2>&1 || true
                fi
                
                return 0
            else
                print_warning "Pin verification failed for $hash"
                # 2025-05-24: Record verification failure and move on - AI
                echo "$hash # Pin verification failed on $(date)" >> "$MISSED_FILE"
                # 2025-05-24: Skip further attempts for verification failures - AI
                print_status "Skipping further attempts due to verification failure"
                return 1
            fi
        else
            local exit_code=$?
            local error_output=$(cat "$LOG_FILE" | tail -10)
            
            # 2025-05-24: Added specific handling for context canceled errors - AI
            if echo "$error_output" | grep -q "context canceled"; then
                print_error "✗ Context canceled for $hash"
                echo "$hash # Context canceled on $(date)" >> "$MISSED_FILE"
                # Skip further attempts for context canceled errors
                print_status "Skipping further attempts due to context canceled error"
                return 1
            elif [[ $exit_code -eq 124 ]]; then
                print_error "✗ Timeout downloading $hash (attempt $attempt/$RETRY_ATTEMPTS)"
            else
                print_error "✗ Failed to migrate $hash (attempt $attempt/$RETRY_ATTEMPTS)"
            fi
            attempt=$((attempt + 1))
            
            if [ $attempt -le $RETRY_ATTEMPTS ]; then
                print_status "Waiting 30 seconds before retry..."
                sleep 30
            fi
        fi
    done
    
    print_error "✗ Failed to migrate $hash after $RETRY_ATTEMPTS attempts"
    # 2025-05-24: Added to record missed hashes for later reference - AI
    echo "$hash" >> "$MISSED_FILE"
    return 1
}

# Enhanced batch migration with better progress tracking
migrate_from_file() {
    # 2025-05-24: Ensure docs directory exists for missed.txt - AI
    mkdir -p "$(dirname "$MISSED_FILE")"
    
    if [[ ! -f "$HASH_LIST_FILE" ]]; then
        print_error "Hash list file not found: $HASH_LIST_FILE"
        print_status "Create a file with one IPFS hash per line"
        print_status "Or run: $0 create-sample"
        exit 1
    fi
    
    # Pre-flight checks
    check_bandwidth_status
    check_azure_storage
    
    # Clean the hash list (remove comments and empty lines)
    local temp_file=$(mktemp)
    grep -v "^#" "$HASH_LIST_FILE" | grep -v "^$" | grep -E "^(Qm[1-9A-HJ-NP-Za-km-z]{44}|bafy[a-z2-7]{55})$" > "$temp_file"
    
    local total_hashes=$(wc -l < "$temp_file")
    local current=0
    local successful=0
    local failed=0
    local skipped=0
    local start_time=$(date +%s)
    
    if [[ $total_hashes -eq 0 ]]; then
        print_error "No valid CIDs found in $HASH_LIST_FILE"
        rm -f "$temp_file"
        exit 1
    fi
    
    print_status "Starting migration of $total_hashes hashes from $HASH_LIST_FILE"
    print_status "Start time: $(date)"
    
    while IFS= read -r hash; do
        current=$((current + 1))
        print_step "Processing $current/$total_hashes: $hash"
        
        # Check if already pinned first (quick check)
        if ipfs pin ls --type=recursive 2>/dev/null | grep -q "^$hash"; then
            print_status "✓ Already pinned, skipping: $hash"
            skipped=$((skipped + 1))
        else
            if migrate_hash "$hash"; then
                successful=$((successful + 1))
            else
                failed=$((failed + 1))
                # 2025-05-24: Also add to missed.txt for consolidated tracking - AI
                echo "$hash" >> "failed_migrations_$(date +%Y%m%d_%H%M%S).txt"
                echo "$hash" >> "$MISSED_FILE"
            fi
        fi
        
        # Progress update with time estimate
        local elapsed=$(($(date +%s) - start_time))
        local avg_time_per_item=$((elapsed / current))
        local remaining_items=$((total_hashes - current))
        local eta_seconds=$((avg_time_per_item * remaining_items))
        local eta_formatted=$(printf '%02d:%02d:%02d' $((eta_seconds/3600)) $((eta_seconds%3600/60)) $((eta_seconds%60)))
        
        print_status "Progress: $current/$total_hashes | Success: $successful | Failed: $failed | Skipped: $skipped | ETA: $eta_formatted"
        
        # Brief pause between migrations and bandwidth check every 5 items
        sleep 2
        if [[ $((current % 5)) -eq 0 ]] && [[ -x "$BANDWIDTH_MANAGER" ]]; then
            $BANDWIDTH_MANAGER check >/dev/null 2>&1 || true
        fi
        
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local total_time_formatted=$(printf '%02d:%02d:%02d' $((total_time/3600)) $((total_time%3600/60)) $((total_time%60)))
    
    print_status "Migration completed!"
    print_status "End time: $(date)"
    print_status "Total time: $total_time_formatted"
    print_status "Total processed: $current"
    print_status "Successful: $successful"
    print_status "Failed: $failed"
    print_status "Skipped (already pinned): $skipped"
    
    if [ $failed -gt 0 ]; then
        print_warning "Failed hashes saved to failed_migrations_*.txt"
        print_status "You can retry failed migrations later"
    fi
    
    # Final repository stats
    print_status "Final repository statistics:"
    ipfs repo stat | tee -a "$LOG_FILE"
}

# Enhanced single hash migration
migrate_single() {
    local hash=$1
    
    if [[ -z "$hash" ]]; then
        print_error "No hash provided"
        exit 1
    fi
    
    # Validate hash format
    if [[ ! "$hash" =~ ^(Qm[1-9A-HJ-NP-Za-km-z]{44}|bafy[a-z2-7]{55})$ ]]; then
        print_error "Invalid IPFS hash format: $hash"
        exit 1
    fi
    
    print_step "Starting migration of single hash: $hash"
    
    # Pre-flight checks
    check_bandwidth_status
    check_azure_storage
    
    # Check if already pinned
    if ipfs pin ls --type=recursive 2>/dev/null | grep -q "^$hash"; then
        print_warning "Hash $hash is already pinned"
        print_status "Content is already in your collection"
        read -p "Do you want to verify and show details anyway? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Verifying existing pin..."
            if timeout 10s ipfs cat "$hash" >/dev/null 2>&1; then
                print_status "✓ Content is accessible"
            else
                print_warning "Content is pinned but not accessible - may need re-download"
                read -p "Re-pin the content? (y/N): " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 0
                fi
                # Remove and re-add pin
                ipfs pin rm "$hash" 2>/dev/null || true
            fi
        else
            exit 0
        fi
    fi
    
    # Estimate storage requirements with size check
    if ! estimate_storage "$hash"; then
        print_status "Skipping migration due to size or availability"
        exit 0
    fi
    
    # Ask for confirmation for large content
    read -p "Do you want to proceed with migration? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Migration cancelled by user"
        exit 0
    fi
    
    # Perform migration
    local start_time=$(date +%s)
    if migrate_hash "$hash"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_status "Single hash migration completed successfully in ${duration}s"
        
        # Show final stats
        print_status "Final repository stats:"
        ipfs repo stat | tee -a "$LOG_FILE"
        
        # Show access URLs
        print_status "Content now accessible at:"
        print_status "  Gateway: http://172.191.4.212:8080/ipfs/$hash"
        print_status "  API: http://172.191.4.212:5001/api/v0/cat?arg=$hash"
        
        # Test quick access
        print_status "Testing content access..."
        if timeout 10s ipfs cat "$hash" >/dev/null 2>&1; then
            print_status "✓ Content verified and accessible"
        else
            print_warning "Content pinned but access test failed"
        fi
        
    else
        print_error "Single hash migration failed"
        exit 1
    fi
}

# Function to check migration status
check_status() {
    print_step "Checking migration status..."
    
    # Show pinned content
    local pinned_count=$(ipfs pin ls --type=recursive | wc -l)
    print_status "Total pinned objects: $pinned_count"
    
    # Show repository stats
    print_status "Repository statistics:"
    ipfs repo stat | tee -a "$LOG_FILE"
    
    # Show recent log entries
    print_status "Recent migration activity:"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 20 "$LOG_FILE"
    fi
}

# Function to create sample hash file
create_sample_file() {
    cat > "$HASH_LIST_FILE" << EOF
# IPFS Hash Migration List
# One hash per line, comments start with #
# Example hashes (replace with your actual hashes):

QmcF4YMFstPKUrS7eJdNe3WD4oPbvog1srTMjwuyRHpGMc
# QmYourHashHere1
# QmYourHashHere2
# QmYourHashHere3

EOF
    print_status "Sample hash file created: $HASH_LIST_FILE"
    print_status "Edit this file and add your IPFS hashes, then run: $0 migrate-file"
}

# Main function
main() {
    echo "========================================"
    echo "      IPFS Data Migration Tool"
    echo "========================================"
    echo ""
    
    case "${1:-help}" in
        "migrate-single")
            check_ipfs
            migrate_single "$2"
            ;;
            
        "migrate-file")
            check_ipfs
            migrate_from_file
            ;;
            
        "status")
            check_ipfs
            check_status
            ;;
            
        "create-sample")
            create_sample_file
            ;;
            
        "retry-failed")
            if [[ -n "$2" && -f "$2" ]]; then
                print_status "Retrying failed migrations from: $2"
                HASH_LIST_FILE="$2"
                migrate_from_file
            else
                print_error "Failed migrations file not provided or not found"
                print_status "Usage: $0 retry-failed failed_migrations_YYYYMMDD_HHMMSS.txt"
                exit 1
            fi
            ;;
            
        "help"|*)
            echo "Usage: $0 {migrate-single|migrate-file|status|create-sample}"
            echo ""
            echo "Commands:"
            echo "  migrate-single HASH  - Migrate a single IPFS hash"
            echo "  migrate-file         - Migrate all hashes from $HASH_LIST_FILE"
            echo "  status              - Check current migration status"
            echo "  create-sample       - Create sample hash list file"
            echo "  retry-failed        - Retry previously failed migrations"
            echo ""
            echo "Examples:"
            echo "  $0 migrate-single QmcF4YMFstPKUrS7eJdNe3WD4oPbvog1srTMjwuyRHpGMc"
            echo "  $0 create-sample && nano $HASH_LIST_FILE && $0 migrate-file"
            echo "  $0 status"
            echo "  $0 retry-failed failed_migrations_20250522_143022.txt"
            echo ""
            echo "Features:"
            echo "  ✓ Integrates with bandwidth management system"
            echo "  ✓ Azure File storage optimization"
            echo "  ✓ Progress tracking with time estimates"
            echo "  ✓ Size limits and validation"
            echo "  ✓ Automatic retry of failed downloads"
            echo "  ✓ Skip already pinned content"
            echo ""
            echo "The script will:"
            echo "  • Check bandwidth status before migration"
            echo "  • Download content from the IPFS network (FREE inbound)"
            echo "  • Store it permanently on your Azure storage"
            echo "  • Pin it to prevent garbage collection"
            echo "  • Verify successful migration"
            echo "  • Log all activities to $LOG_FILE"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"