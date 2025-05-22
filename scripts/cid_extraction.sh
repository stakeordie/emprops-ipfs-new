#!/bin/bash

# CID Extraction Scripts for Common IPFS Hosting Services
# Choose the appropriate script based on your hosting provider

# =============================================================================
# PINATA EXTRACTION
# =============================================================================
extract_pinata_cids() {
    local api_key="$1"
    local secret_key="$2"
    local output_file="pinata_cids.txt"
    
    echo "Extracting CIDs from Pinata..."
    
    # Get all pinned files
    curl -X GET \
        -H "pinata_api_key: $api_key" \
        -H "pinata_secret_api_key: $secret_key" \
        "https://api.pinata.cloud/data/pinList?status=pinned" \
        | jq -r '.rows[].ipfs_pin_hash' > "$output_file"
    
    echo "Pinata CIDs saved to: $output_file"
    echo "Total CIDs found: $(wc -l < $output_file)"
}

# Usage: extract_pinata_cids "your_api_key" "your_secret_key"

# =============================================================================
# WEB3.STORAGE EXTRACTION  
# =============================================================================
extract_web3storage_cids() {
    local api_token="$1"
    local output_file="web3storage_cids.txt"
    
    echo "Extracting CIDs from Web3.Storage..."
    
    # Get all uploads
    curl -X GET \
        -H "Authorization: Bearer $api_token" \
        "https://api.web3.storage/user/uploads" \
        | jq -r '.[] | select(.dagSize != null) | .cid' > "$output_file"
    
    echo "Web3.Storage CIDs saved to: $output_file"
    echo "Total CIDs found: $(wc -l < $output_file)"
}

# Usage: extract_web3storage_cids "your_api_token"

# =============================================================================
# INFURA EXTRACTION
# =============================================================================
extract_infura_cids() {
    local project_id="$1"
    local project_secret="$2"
    local output_file="infura_cids.txt"
    
    echo "Extracting CIDs from Infura..."
    
    # Note: Infura doesn't have a direct "list all" API
    # You'll need to maintain your own list or use their pin management
    echo "Infura requires manual CID list maintenance"
    echo "Check your application logs or database for CIDs"
    echo "Or use Infura's pin management dashboard"
}

# =============================================================================
# FLEEK EXTRACTION
# =============================================================================
extract_fleek_cids() {
    local api_key="$1"
    local output_file="fleek_cids.txt"
    
    echo "Extracting CIDs from Fleek..."
    
    # Fleek GraphQL API
    curl -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d '{"query": "query { getFilesByTeam { ipfsHash } }"}' \
        "https://api.fleek.co/graphql" \
        | jq -r '.data.getFilesByTeam[].ipfsHash' > "$output_file"
    
    echo "Fleek CIDs saved to: $output_file"
    echo "Total CIDs found: $(wc -l < $output_file)"
}

# =============================================================================
# GENERIC WEB SCRAPING (Dashboard/Admin Panel)
# =============================================================================
extract_from_dashboard() {
    local dashboard_url="$1"
    local output_file="dashboard_cids.txt"
    
    echo "Extracting CIDs from web dashboard..."
    echo "This requires manual steps:"
    echo "1. Log into your dashboard at: $dashboard_url"
    echo "2. Navigate to your files/pins list"
    echo "3. Export or copy all CIDs"
    echo "4. Save them to: $output_file"
    echo "5. One CID per line"
}

# =============================================================================
# APPLICATION LOGS/DATABASE EXTRACTION
# =============================================================================
extract_from_logs() {
    local log_file="$1"
    local output_file="logs_cids.txt"
    
    echo "Extracting CIDs from application logs..."
    
    # Look for IPFS hash patterns (Qm... or bafy...)
    grep -oE "(Qm[1-9A-HJ-NP-Za-km-z]{44}|bafy[a-z2-7]{55})" "$log_file" | sort | uniq > "$output_file"
    
    echo "CIDs extracted from logs to: $output_file"
    echo "Total unique CIDs found: $(wc -l < $output_file)"
}

# =============================================================================
# DATABASE EXTRACTION (Generic SQL)
# =============================================================================
extract_from_database() {
    local db_connection="$1"  # e.g., "postgresql://user:pass@host/db"
    local table_name="$2"
    local cid_column="$3"
    local output_file="database_cids.txt"
    
    echo "Extracting CIDs from database..."
    
    # Generic SQL query (adjust for your database)
    psql "$db_connection" -t -c "SELECT DISTINCT $cid_column FROM $table_name WHERE $cid_column IS NOT NULL;" > "$output_file"
    
    # Clean up the output
    sed -i '/^$/d' "$output_file"  # Remove empty lines
    sed -i 's/^[ \t]*//;s/[ \t]*$//' "$output_file"  # Trim whitespace
    
    echo "Database CIDs saved to: $output_file"
    echo "Total CIDs found: $(wc -l < $output_file)"
}

# =============================================================================
# IPFS NODE EXTRACTION (if you have access to the node)
# =============================================================================
extract_from_ipfs_node() {
    local ipfs_api_url="$1"  # e.g., "http://your-node:5001"
    local output_file="node_cids.txt"
    
    echo "Extracting pinned CIDs from IPFS node..."
    
    # Get all pinned content
    curl -X POST "$ipfs_api_url/api/v0/pin/ls?type=recursive" \
        | jq -r '.Keys | keys[]' > "$output_file"
    
    echo "Node CIDs saved to: $output_file"
    echo "Total pinned CIDs found: $(wc -l < $output_file)"
}

# =============================================================================
# CID VALIDATION AND CLEANUP
# =============================================================================
validate_and_clean_cids() {
    local input_file="$1"
    local output_file="${input_file%.txt}_cleaned.txt"
    
    echo "Validating and cleaning CID list..."
    
    # Remove duplicates and invalid entries
    sort "$input_file" | uniq | grep -E "^(Qm[1-9A-HJ-NP-Za-km-z]{44}|bafy[a-z2-7]{55})$" > "$output_file"
    
    echo "Cleaned CIDs saved to: $output_file"
    echo "Original count: $(wc -l < $input_file)"
    echo "Cleaned count: $(wc -l < $output_file)"
    echo "Removed: $(($(wc -l < $input_file) - $(wc -l < $output_file))) invalid/duplicate entries"
}

# =============================================================================
# INTERACTIVE EXTRACTION WIZARD
# =============================================================================
extraction_wizard() {
    echo "========================================"
    echo "    IPFS CID Extraction Wizard"
    echo "========================================"
    echo ""
    echo "Which hosting service are you using?"
    echo "1) Pinata"
    echo "2) Web3.Storage"
    echo "3) Infura"
    echo "4) Fleek"
    echo "5) Custom/Other (manual extraction)"
    echo "6) I have access to the IPFS node directly"
    echo "7) Extract from application logs"
    echo "8) Extract from database"
    echo ""
    read -p "Choose an option (1-8): " choice
    
    case $choice in
        1)
            read -p "Enter Pinata API Key: " api_key
            read -p "Enter Pinata Secret Key: " secret_key
            extract_pinata_cids "$api_key" "$secret_key"
            ;;
        2)
            read -p "Enter Web3.Storage API Token: " api_token
            extract_web3storage_cids "$api_token"
            ;;
        3)
            read -p "Enter Infura Project ID: " project_id
            read -p "Enter Infura Project Secret: " project_secret
            extract_infura_cids "$project_id" "$project_secret"
            ;;
        4)
            read -p "Enter Fleek API Key: " api_key
            extract_fleek_cids "$api_key"
            ;;
        5)
            read -p "Enter dashboard URL: " dashboard_url
            extract_from_dashboard "$dashboard_url"
            ;;
        6)
            read -p "Enter IPFS API URL (e.g., http://node:5001): " api_url
            extract_from_ipfs_node "$api_url"
            ;;
        7)
            read -p "Enter path to log file: " log_file
            extract_from_logs "$log_file"
            ;;
        8)
            read -p "Enter database connection string: " db_conn
            read -p "Enter table name: " table
            read -p "Enter CID column name: " column
            extract_from_database "$db_conn" "$table" "$column"
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    
    # Ask about validation
    echo ""
    read -p "Do you want to validate and clean the extracted CIDs? (y/N): " validate
    if [[ $validate =~ ^[Yy]$ ]]; then
        # Find the most recent output file
        latest_file=$(ls -t *_cids.txt 2>/dev/null | head -1)
        if [[ -n "$latest_file" ]]; then
            validate_and_clean_cids "$latest_file"
        else
            echo "No CID file found to validate"
        fi
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# If script is run directly, start the wizard
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    extraction_wizard
fi

# =============================================================================
# USAGE EXAMPLES
# =============================================================================

# Direct function calls:
# extract_pinata_cids "your_api_key" "your_secret_key"
# extract_web3storage_cids "your_api_token"
# extract_from_logs "/path/to/app.log"
# validate_and_clean_cids "raw_cids.txt"