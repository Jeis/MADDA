#!/bin/sh
set -e

# API Gateway Docker Entrypoint Script
# Ensures proper directory permissions at runtime

# Note: This runs as root initially to fix permissions,
# then switches to the spatial user for the actual application

# Create logging directory if it doesn't exist (in case of volume mounts)
mkdir -p /var/log/spatial/api-gateway

# Ensure proper ownership for the spatial user
# This handles cases where volumes might have incorrect permissions
chown -R spatial:spatial /var/log/spatial/api-gateway /app/logs /app/temp /app/cache 2>/dev/null || true

# Switch to spatial user and execute the command
exec gosu spatial "$@"