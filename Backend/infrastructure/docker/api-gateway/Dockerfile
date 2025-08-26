# Enterprise API Gateway - Multi-stage build with Phase 2 package validation
# Stage 1: Package Validation (Phase 2 Compliance)
FROM python:3.12-slim AS validator

# Install validation tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    && pip install --no-cache-dir pip-audit pip-licenses pip-tools \
    && rm -rf /var/lib/apt/lists/*

# Copy package registry and requirements
COPY infrastructure/docker/package-registry.yaml /registry.yaml
COPY api_gateway/requirements.txt /requirements.txt

# Validate packages against central registry
RUN pip-audit -r /requirements.txt --format json > /audit.json || true \
    && critical_count=$(jq '[.vulnerabilities[]? | select(.severity == "CRITICAL")] | length' /audit.json) \
    && high_count=$(jq '[.vulnerabilities[]? | select(.severity == "HIGH")] | length' /audit.json) \
    && if [ "$critical_count" -gt 0 ] || [ "$high_count" -gt 0 ]; then \
        echo "Critical/High vulnerabilities found, failing build"; \
        jq '.vulnerabilities[] | select(.severity == "CRITICAL" or .severity == "HIGH")' /audit.json; \
        exit 1; \
    fi

# Generate lockfile for reproducibility
RUN pip-compile --generate-hashes --output-file=/requirements.lock /requirements.txt

# Stage 2: Builder
FROM python:3.12-slim AS builder

# Metadata
LABEL maintainer="platform@spatialvr.com"
LABEL version="2.0.0"
LABEL description="Spatial Platform API Gateway - Enterprise Grade with Security Hardening"
LABEL package-validation="Phase 2 Compliant"

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy validated and locked dependencies
COPY --from=validator /requirements.lock /requirements.lock
COPY api_gateway/requirements.txt /requirements.txt

# Install dependencies using lockfile
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r /requirements.lock

# Stage 2: Runtime
FROM python:3.12-slim

# Metadata
LABEL maintainer="platform@spatialvr.com"
LABEL version="2.0.0"
LABEL description="Spatial Platform API Gateway - Production Runtime"

# Security: Create non-root user with minimal privileges
RUN groupadd --gid 1000 spatial \
    && useradd --uid 1000 --gid spatial --shell /bin/false --no-create-home spatial

# Install only runtime dependencies and su-exec for privilege dropping
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gosu \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives \
    && rm -rf /tmp/* /var/tmp/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Set environment
ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app
ENV PYTHONIOENCODING=utf-8

# Set working directory
WORKDIR /app

# Copy application code with proper ownership
COPY --chown=spatial:spatial api_gateway/ /app/
COPY --chown=spatial:spatial infrastructure/observability/ /app/infrastructure/observability/
COPY --chown=root:root infrastructure/docker/scripts/wait-for-it.sh /usr/local/bin/
COPY --chown=root:root infrastructure/docker/api-gateway/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/wait-for-it.sh /docker-entrypoint.sh

# Create required directories with proper permissions
RUN mkdir -p /app/logs /app/temp /app/cache /var/log/spatial/api-gateway \
    && chown -R spatial:spatial /app /var/log/spatial \
    && chmod 755 /app \
    && chmod 755 /app/logs /app/temp /app/cache /var/log/spatial /var/log/spatial/api-gateway

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Use entrypoint for permission handling
ENTRYPOINT ["/docker-entrypoint.sh"]

# Production command with optimized settings
CMD ["uvicorn", "app:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "1", \
     "--loop", "uvloop", \
     "--access-log", \
     "--log-config", "/app/logging.json"]