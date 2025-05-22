# IPFS Bandwidth Manager

A tool for monitoring and limiting IPFS traffic based on configurable settings.

## Features

- Monitor IPFS bandwidth usage in real-time
- Set daily and monthly bandwidth limits
- Automatically switch between full and restricted modes based on usage
- Command-line interface for management
- Automated setup with cron jobs

## Installation

1. Clone this repository
2. Run the setup script to configure cron jobs:
   ```
   ./setup-ipfs-cron.sh install
   ```

## Usage

The bandwidth manager provides several commands:

```
./ipfs-bandwidth-manager {check|status|reset|force-restricted|force-full}
```

- `check` - Check current usage and apply restrictions if needed
- `status` - Show current bandwidth usage and mode
- `reset` - Reset all counters and enable full mode
- `force-restricted` - Force restricted mode (own content only)
- `force-full` - Force full participation mode

## Configuration

Edit the configuration variables at the top of the `ipfs-bandwidth-manager` script to adjust:

- Daily bandwidth limit (GB)
- Monthly bandwidth limit (GB)
- Log file locations

## License

MIT

<!-- FLAG: Created 2025-05-22T10:50:12-04:00 -->
