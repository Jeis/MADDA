#!/bin/sh
set -e

# Localization Service Docker Entrypoint Script
# Ensures proper directory permissions at runtime for SLAM/VIO operations

# Note: This runs as root initially to fix permissions,
# then switches to the spatial user for the actual application

# Create required directories if they don't exist (in case of volume mounts)
mkdir -p /var/log/spatial/localization
mkdir -p /app/vocab  # For SLAM vocabulary files

# Ensure proper ownership for the spatial user
# This handles cases where volumes might have incorrect permissions
chown -R spatial:spatial /var/log/spatial/localization /app/logs /app/temp /app/cache /app/vocab 2>/dev/null || true

# Switch to spatial user and execute the command
exec gosu spatial "$@"