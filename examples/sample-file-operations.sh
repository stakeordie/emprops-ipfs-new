#!/bin/bash

# IPFS Sample File Operations
# Examples of common IPFS file operations
# FLAG: Created 2025-05-22T10:54:11-04:00

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
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

# Create a test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
echo "Working in temporary directory: $TEST_DIR"

# Example 1: Adding files to IPFS
print_header "ADDING FILES TO IPFS"

# Create a test file
echo "Hello, IPFS!" > hello.txt
run_command "cat hello.txt"

# Add the file to IPFS
run_command "ipfs add hello.txt"

# Add a directory recursively
mkdir -p test-dir/nested
echo "Nested file content" > test-dir/nested/file.txt
echo "Root file content" > test-dir/root.txt
run_command "ipfs add -r test-dir"

# Example 2: Retrieving files from IPFS
print_header "RETRIEVING FILES FROM IPFS"

# Get the file we just added
CID=$(ipfs add -q hello.txt)
run_command "ipfs cat $CID"

# Save to a new file
run_command "ipfs cat $CID > retrieved.txt"
run_command "diff hello.txt retrieved.txt"

# Example 3: Working with IPFS paths
print_header "WORKING WITH IPFS PATHS"

# Add a directory with a named file
mkdir -p named-dir
echo "This is a named file" > named-dir/named-file.txt
DIR_CID=$(ipfs add -r -Q named-dir)

# Access the file by path
run_command "ipfs ls $DIR_CID"
run_command "ipfs cat /ipfs/$DIR_CID/named-file.txt"

# Example 4: Pinning content
print_header "PINNING CONTENT"

# Pin a file to keep it permanently
run_command "ipfs pin add $CID"

# List pinned content
run_command "ipfs pin ls | grep $CID"

# Example 5: IPFS MFS (Mutable File System)
print_header "USING IPFS MFS"

# Create directories in MFS
run_command "ipfs files mkdir -p /mfs-test/documents"

# Add files to MFS
run_command "ipfs files cp /ipfs/$CID /mfs-test/documents/hello.txt"

# List files in MFS
run_command "ipfs files ls -l /mfs-test"
run_command "ipfs files ls -l /mfs-test/documents"

# Read a file from MFS
run_command "ipfs files read /mfs-test/documents/hello.txt"

# Example 6: IPNS (InterPlanetary Name System)
print_header "USING IPNS"

# Publish content to IPNS (using your node's key)
run_command "ipfs name publish $DIR_CID"

# Get your node ID
NODE_ID=$(ipfs id -f='<id>')
echo "Your node ID: $NODE_ID"

# Example 7: Garbage collection
print_header "GARBAGE COLLECTION"

# Create a temporary file
echo "Temporary content" > temp.txt
TEMP_CID=$(ipfs add -q temp.txt)
echo "Added temporary file with CID: $TEMP_CID"

# Run garbage collection
run_command "ipfs repo gc"

# Clean up
print_header "CLEANING UP"
cd /tmp
rm -rf "$TEST_DIR"
echo "Removed temporary directory: $TEST_DIR"

print_header "COMPLETE"
echo "All examples completed successfully!"
