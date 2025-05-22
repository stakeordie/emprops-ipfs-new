# IPFS Bandwidth Management

This document explains how the IPFS bandwidth management system works and how to configure it for your needs.

## Overview

The bandwidth management system monitors IPFS traffic and automatically switches between "full" and "restricted" modes based on configurable daily and monthly limits.

- **Full Mode**: Normal IPFS operation with full network participation
- **Restricted Mode**: Limited operation serving only your own content

## How It Works

The bandwidth manager:

1. Periodically checks IPFS bandwidth usage (every 5 minutes by default)
2. Tracks daily and monthly outbound traffic
3. Compares usage against configured limits
4. Automatically switches modes when limits are reached
5. Resets counters at the start of each day/month

## Configuration

Edit the configuration variables at the top of the `scripts/ipfs-bandwidth-manager.sh` script:

```bash
# Configuration
DAILY_LIMIT_GB=10      # Daily bandwidth limit in GB
MONTHLY_LIMIT_GB=250   # Monthly bandwidth limit in GB
STATS_FILE="/var/log/ipfs-bandwidth-stats.json"
CONFIG_FILE="/etc/ipfs-bandwidth-config"
LOG_FILE="/var/log/ipfs-bandwidth.log"
```

## Mode Details

### Full Mode

In full mode, IPFS operates with normal network participation:

- Higher connection limits (HighWater: 100, LowWater: 50)
- Gateway in online mode (can serve any content)
- Full DHT participation (helps other nodes find content)

### Restricted Mode

In restricted mode, IPFS operates with limited network participation:

- Lower connection limits (HighWater: 5, LowWater: 2)
- Gateway in offline mode (only serves locally available content)
- Limited DHT participation (client mode only)

## Commands

The bandwidth manager provides several commands:

```bash
ipfs-bandwidth-manager {check|status|reset|force-restricted|force-full}
```

- `check`: Check current usage and apply restrictions if needed
- `status`: Show current bandwidth usage and mode
- `reset`: Reset all counters and enable full mode
- `force-restricted`: Force restricted mode (own content only)
- `force-full`: Force full participation mode

## Monitoring

Monitor bandwidth usage with:

```bash
# Check current status
ipfs-bandwidth-manager status

# View logs
cat /var/log/ipfs-bandwidth.log

# View daily reports
cat /var/log/ipfs-daily-report.log
```

## Customization

### Adjusting Thresholds

For more gradual throttling, you can modify the script to add intermediate modes with different connection limits.

### Time-based Rules

To implement time-based rules (e.g., different limits during peak hours), you can modify the `check_bandwidth` function to consider the current time of day.

### Advanced Monitoring

For more detailed monitoring, consider integrating with monitoring tools like Prometheus and Grafana.

## Troubleshooting

If bandwidth management isn't working as expected:

1. Check the log file: `/var/log/ipfs-bandwidth.log`
2. Verify IPFS is running: `sudo systemctl status ipfs`
3. Reset counters if needed: `ipfs-bandwidth-manager reset`
4. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more help

<!-- FLAG: Created 2025-05-22T10:54:11-04:00 -->
