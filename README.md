# IPFS Bandwidth Manager

A comprehensive solution for deploying, monitoring, and limiting IPFS traffic on Azure VMs based on configurable settings.

## Features

- Complete IPFS setup for Azure VMs with persistent storage
- Bandwidth monitoring and automatic traffic limiting
- Configurable daily and monthly bandwidth limits
- Automatic mode switching between full and restricted participation
- Detailed documentation and examples

## Repository Structure

```
emprops-ipfs-new/
├── README.md                           # Main documentation
├── scripts/
│   ├── ipfs-bandwidth-manager.sh       # Main bandwidth control script
│   ├── setup-ipfs-cron.sh              # Cron setup script
│   └── install-ipfs-azure.sh           # Complete IPFS + Azure setup
├── configs/
│   ├── ipfs-config.json                # IPFS configuration template
│   ├── systemd-service.txt             # systemd service file
│   └── azure-mount-commands.txt        # Azure file share mount commands
├── docs/
│   ├── SETUP.md                        # Step-by-step setup guide
│   ├── BANDWIDTH-MANAGEMENT.md         # Bandwidth control documentation
│   ├── TROUBLESHOOTING.md              # Common issues and solutions
│   └── COST-ESTIMATION.md              # Azure cost planning
└── examples/
    ├── sample-file-operations.sh       # Example IPFS operations
    └── monitoring-commands.sh          # Useful monitoring commands
```

## Quick Start

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/stakeordie/emprops-ipfs-new.git
   cd emprops-ipfs-new
   ```

2. For a complete setup on an Azure VM:
   ```bash
   bash scripts/install-ipfs-azure.sh
   ```

3. For just the bandwidth management component:
   ```bash
   sudo cp scripts/ipfs-bandwidth-manager.sh /usr/local/bin/ipfs-bandwidth-manager
   sudo chmod +x /usr/local/bin/ipfs-bandwidth-manager
   bash scripts/setup-ipfs-cron.sh install
   ```

### Usage

The bandwidth manager provides several commands:

```bash
ipfs-bandwidth-manager {check|status|reset|force-restricted|force-full}
```

- `check` - Check current usage and apply restrictions if needed
- `status` - Show current bandwidth usage and mode
- `reset` - Reset all counters and enable full mode
- `force-restricted` - Force restricted mode (own content only)
- `force-full` - Force full participation mode

## Documentation

- [Setup Guide](docs/SETUP.md) - Detailed installation instructions
- [Bandwidth Management](docs/BANDWIDTH-MANAGEMENT.md) - How the bandwidth control works
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Cost Estimation](docs/COST-ESTIMATION.md) - Azure cost planning guide

## Examples

- [Sample File Operations](examples/sample-file-operations.sh) - Common IPFS file operations
- [Monitoring Commands](examples/monitoring-commands.sh) - Useful commands for monitoring

## License

MIT

<!-- FLAG: Created 2025-05-22T10:54:11-04:00 -->
