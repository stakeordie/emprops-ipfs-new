#!/bin/bash

# IPFS Bandwidth Manager - Cron Setup Script
# This script sets up automated monitoring for IPFS bandwidth management

set -e  # Exit on any error

# Configuration
SCRIPT_NAME="ipfs-bandwidth-manager"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
LOG_DIR="/var/log"
CRON_BACKUP="/tmp/crontab_backup_$(date +%Y%m%d_%H%M%S)"

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
        print_error "Run as the same user that runs IPFS (typically azureuser)"
        exit 1
    fi
    print_status "Running as user: $(whoami)"
}

# Function to install dependencies
install_dependencies() {
    print_step "Installing required dependencies..."
    
    # Check if dependencies are installed
    local deps_needed=()
    
    if ! command_exists bc; then
        deps_needed+=("bc")
    fi
    
    if ! command_exists jq; then
        deps_needed+=("jq")
    fi
    
    if ! command_exists crontab; then
        deps_needed+=("cron")
    fi
    
    if [[ ${#deps_needed[@]} -eq 0 ]]; then
        print_status "All dependencies already installed"
        return 0
    fi
    
    print_status "Installing missing dependencies: ${deps_needed[*]}"
    sudo apt update
    sudo apt install -y "${deps_needed[@]}"
    
    # Start cron service if it's not running
    if ! systemctl is-active --quiet cron; then
        print_status "Starting cron service..."
        sudo systemctl start cron
        sudo systemctl enable cron
    fi
}

# Function to check if IPFS bandwidth manager script exists
check_bandwidth_script() {
    print_step "Checking for IPFS bandwidth manager script..."
    
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        print_error "IPFS bandwidth manager script not found at $SCRIPT_PATH"
        print_error "Please ensure you have copied the bandwidth manager script to $SCRIPT_PATH"
        print_error "And made it executable with: sudo chmod +x $SCRIPT_PATH"
        exit 1
    fi
    
    if [[ ! -x "$SCRIPT_PATH" ]]; then
        print_warning "Making bandwidth manager script executable..."
        sudo chmod +x "$SCRIPT_PATH"
    fi
    
    print_status "Bandwidth manager script found and executable"
}

# Function to backup existing crontab
backup_crontab() {
    print_step "Backing up existing crontab..."
    
    if crontab -l >/dev/null 2>&1; then
        crontab -l > "$CRON_BACKUP"
        print_status "Existing crontab backed up to: $CRON_BACKUP"
    else
        print_status "No existing crontab found"
        touch "$CRON_BACKUP"
    fi
}

# Function to check if cron jobs already exist
check_existing_cron() {
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        print_warning "IPFS bandwidth manager cron jobs already exist!"
        echo ""
        echo "Existing cron jobs:"
        crontab -l 2>/dev/null | grep "$SCRIPT_NAME" || true
        echo ""
        read -p "Do you want to remove existing jobs and add new ones? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Keeping existing cron jobs. Exiting."
            exit 0
        fi
        return 1  # Need to remove existing
    fi
    return 0  # No existing jobs
}

# Function to remove existing IPFS bandwidth cron jobs
remove_existing_cron() {
    print_step "Removing existing IPFS bandwidth manager cron jobs..."
    
    # Get current crontab, remove lines with our script, save back
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" || true) | crontab -
    
    print_status "Existing IPFS bandwidth manager cron jobs removed"
}

# Function to add cron jobs
add_cron_jobs() {
    print_step "Adding IPFS bandwidth manager cron jobs..."
    
    # Create temporary file with new cron jobs
    local temp_cron=$(mktemp)
    
    # Get existing crontab (if any)
    crontab -l 2>/dev/null > "$temp_cron" || true
    
    # Add our cron jobs
    cat >> "$temp_cron" << EOF

# IPFS Bandwidth Manager - Auto-generated on $(date)
# Check bandwidth usage every 5 minutes
*/5 * * * * $SCRIPT_PATH check >/dev/null 2>&1

# Daily status report at midnight
0 0 * * * $SCRIPT_PATH status >> $LOG_DIR/ipfs-daily-report.log 2>&1

# Weekly detailed log cleanup (keep last 30 days)
0 2 * * 0 find $LOG_DIR -name "ipfs-bandwidth*.log" -mtime +30 -delete 2>/dev/null || true

EOF
    
    # Install the new crontab
    crontab "$temp_cron"
    rm "$temp_cron"
    
    print_status "Cron jobs added successfully!"
}

# Function to setup log directories and permissions
setup_logging() {
    print_step "Setting up logging directories and permissions..."
    
    # Ensure log directory exists and has correct permissions
    sudo mkdir -p "$LOG_DIR"
    
    # Create log files if they don't exist
    local log_files=(
        "$LOG_DIR/ipfs-bandwidth.log"
        "$LOG_DIR/ipfs-bandwidth-stats.json"
        "$LOG_DIR/ipfs-daily-report.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ ! -f "$log_file" ]]; then
            sudo touch "$log_file"
        fi
        sudo chown "$USER:$USER" "$log_file"
    done
    
    print_status "Logging setup complete"
}

# Function to test the setup
test_setup() {
    print_step "Testing the IPFS bandwidth manager setup..."
    
    # Test script execution
    if "$SCRIPT_PATH" status >/dev/null 2>&1; then
        print_status "✓ Bandwidth manager script executes correctly"
    else
        print_error "✗ Bandwidth manager script failed to execute"
        return 1
    fi
    
    # Test cron job syntax
    if crontab -l | grep -q "$SCRIPT_NAME"; then
        print_status "✓ Cron jobs installed correctly"
    else
        print_error "✗ Cron jobs not found"
        return 1
    fi
    
    # Test log file creation
    "$SCRIPT_PATH" check
    if [[ -f "$LOG_DIR/ipfs-bandwidth.log" ]]; then
        print_status "✓ Log file creation working"
    else
        print_warning "✗ Log file not created (may be permissions issue)"
    fi
    
    print_status "Setup test completed successfully!"
}

# Function to show current status
show_status() {
    print_step "Current IPFS bandwidth manager status:"
    echo ""
    
    # Show cron jobs
    echo "=== CRON JOBS ==="
    crontab -l 2>/dev/null | grep "$SCRIPT_NAME" || echo "No IPFS bandwidth manager cron jobs found"
    echo ""
    
    # Show current bandwidth status
    echo "=== BANDWIDTH STATUS ==="
    if [[ -x "$SCRIPT_PATH" ]]; then
        "$SCRIPT_PATH" status
    else
        echo "Bandwidth manager script not found or not executable"
    fi
    echo ""
    
    # Show recent log entries
    echo "=== RECENT LOG ENTRIES (last 10) ==="
    if [[ -f "$LOG_DIR/ipfs-bandwidth.log" ]]; then
        tail -n 10 "$LOG_DIR/ipfs-bandwidth.log"
    else
        echo "No log file found"
    fi
}

# Function to remove all cron jobs and cleanup
cleanup() {
    print_step "Removing IPFS bandwidth manager cron jobs and cleaning up..."
    
    # Remove cron jobs
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" || true) | crontab -
        print_status "Cron jobs removed"
    else
        print_status "No cron jobs found to remove"
    fi
    
    # Ask about log files
    read -p "Do you want to remove log files too? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -f "$LOG_DIR/ipfs-bandwidth"* "$LOG_DIR/ipfs-daily-report.log" 2>/dev/null || true
        print_status "Log files removed"
    fi
    
    print_status "Cleanup completed"
}

# Main function
main() {
    echo "=================================================="
    echo "  IPFS Bandwidth Manager - Cron Setup Script"
    echo "=================================================="
    echo ""
    
    case "${1:-install}" in
        "install")
            check_user
            install_dependencies
            check_bandwidth_script
            backup_crontab
            
            if ! check_existing_cron; then
                remove_existing_cron
            fi
            
            add_cron_jobs
            setup_logging
            test_setup
            
            echo ""
            print_status "🎉 IPFS Bandwidth Manager cron setup completed successfully!"
            echo ""
            print_status "The system will now:"
            print_status "  • Check bandwidth usage every 5 minutes"
            print_status "  • Generate daily reports at midnight"
            print_status "  • Clean up old logs weekly"
            echo ""
            print_status "You can check status with: $SCRIPT_PATH status"
            print_status "View logs with: tail -f $LOG_DIR/ipfs-bandwidth.log"
            ;;
            
        "status")
            show_status
            ;;
            
        "remove"|"cleanup")
            cleanup
            ;;
            
        "test")
            check_user
            test_setup
            ;;
            
        *)
            echo "Usage: $0 {install|status|remove|test}"
            echo ""
            echo "Commands:"
            echo "  install  - Install and setup cron jobs (default)"
            echo "  status   - Show current status and recent logs"
            echo "  remove   - Remove cron jobs and optionally log files"
            echo "  test     - Test the current setup"
            echo ""
            echo "Examples:"
            echo "  $0 install  # Setup everything"
            echo "  $0 status   # Check current status"
            echo "  $0 remove   # Clean up everything"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"