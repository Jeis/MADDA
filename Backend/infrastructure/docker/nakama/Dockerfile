# Enterprise Nakama Server for Spatial Platform
# Architecture-aware image selection with performance optimization

ARG NAKAMA_IMAGE=heroiclabs/nakama:3.30.0
ARG NAKAMA_PLATFORM=linux/amd64

FROM --platform=${NAKAMA_PLATFORM} ${NAKAMA_IMAGE}

# Temporarily switch to root for setup
USER root

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    postgresql-client \
    netcat-openbsd \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives \
    && rm -rf /tmp/* /var/tmp/* \
    && ln -sf /usr/bin/nc.openbsd /usr/bin/nc

# Copy and setup dependency management scripts with proper permissions
COPY --chown=root:root infrastructure/docker/scripts/wait-for-it.sh /usr/local/bin/wait-for-it.sh
COPY --chown=root:root infrastructure/docker/scripts/wait-for-postgres.sh /usr/local/bin/wait-for-postgres.sh
RUN chmod 755 /usr/local/bin/wait-for-it.sh /usr/local/bin/wait-for-postgres.sh

# Create nakama user if it doesn't exist and setup directories
RUN id nakama >/dev/null 2>&1 || useradd -r -u 9999 -s /bin/false nakama \
    && mkdir -p /nakama/data /nakama/logs \
    && chown -R nakama:nakama /nakama \
    && chmod 755 /nakama/data /nakama/logs

# Switch to non-root user for security
USER nakama

# Enhanced health check with proper endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:7350/healthcheck || curl -f http://localhost:7350/ || exit 1

# Expose standard Nakama ports
# 7349: gRPC API
# 7350: HTTP API  
# 7351: Console
# 9100: Prometheus metrics
EXPOSE 7349 7350 7351 9100

# Set working directory
WORKDIR /nakama