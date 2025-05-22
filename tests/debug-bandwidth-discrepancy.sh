#!/bin/bash

echo "=== Bandwidth Discrepancy Debug ==="
echo "Date: $(date)"
echo ""

echo "1. Raw IPFS Stats:"
ipfs stats bw
echo ""

echo "2. IPFS TotalOut parsing:"
STATS=$(ipfs stats bw)
TOTAL_OUT_LINE=$(echo "$STATS" | grep "TotalOut")
echo "TotalOut line: '$TOTAL_OUT_LINE'"
VALUE=$(echo "$TOTAL_OUT_LINE" | awk '{print $2}')
UNIT=$(echo "$TOTAL_OUT_LINE" | awk '{print $3}')
echo "Value: '$VALUE', Unit: '$UNIT'"
echo ""

echo "3. Bandwidth Manager Stats File:"
cat /var/log/ipfs-bandwidth-stats.json | jq .
echo ""

echo "4. Manual Conversions:"
DAILY_BYTES=$(cat /var/log/ipfs-bandwidth-stats.json | jq -r '.daily_usage')
MONTHLY_BYTES=$(cat /var/log/ipfs-bandwidth-stats.json | jq -r '.monthly_usage')
echo "Daily usage (bytes): $DAILY_BYTES"
echo "Monthly usage (bytes): $MONTHLY_BYTES"
DAILY_GB=$(echo "scale=6; $DAILY_BYTES / 1073741824" | bc -l)
MONTHLY_GB=$(echo "scale=6; $MONTHLY_BYTES / 1073741824" | bc -l)
echo "Daily usage (GB): $DAILY_GB"
echo "Monthly usage (GB): $MONTHLY_GB"
echo ""

echo "5. What bandwidth manager reports:"
ipfs-bandwidth-manager status