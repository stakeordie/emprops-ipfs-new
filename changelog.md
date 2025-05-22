# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-05-22

### Added
- Comprehensive directory structure for better organization
- New `scripts/install-ipfs-azure.sh` for complete Azure VM setup
- Configuration templates in `configs/` directory:
  - IPFS configuration template (ipfs-config.json)
  - Systemd service file (systemd-service.txt)
  - Azure mount commands (azure-mount-commands.txt)
- Detailed documentation in `docs/` directory:
  - SETUP.md with step-by-step installation guide
  - BANDWIDTH-MANAGEMENT.md explaining the bandwidth control system
  - TROUBLESHOOTING.md with common issues and solutions
  - COST-ESTIMATION.md for Azure cost planning
- Example scripts in `examples/` directory:
  - sample-file-operations.sh demonstrating common IPFS operations
  - monitoring-commands.sh with useful monitoring commands

### Changed
- Moved existing scripts to the `scripts/` directory
- Renamed scripts with .sh extension for clarity
- Updated README.md with new directory structure and improved documentation

## [0.1.0] - 2025-05-22

### Added
- Initial repository setup
- IPFS bandwidth manager script for monitoring and limiting IPFS traffic
- Setup script for configuring cron jobs
- Basic project structure with README, package.json, and .gitignore

<!-- FLAG: Created 2025-05-22T10:54:11-04:00 -->
