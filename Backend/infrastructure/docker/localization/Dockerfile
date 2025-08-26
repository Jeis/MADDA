# Enterprise Localization Service - Multi-stage build for optimization
# Stage 1: Builder with scientific computing support
FROM python:3.11-slim AS builder

# Enhanced metadata matching API Gateway standards
LABEL maintainer="platform@spatialvr.com"
LABEL version="2.0.0"
LABEL description="Spatial Platform Localization Service - Enterprise Grade SLAM/VIO"

# Install build dependencies for scientific computing
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libeigen3-dev \
    libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies in isolated environment
COPY localization_service/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

# Stage 2: Production runtime
FROM python:3.11-slim

# Enhanced metadata
LABEL maintainer="platform@spatialvr.com"
LABEL version="2.0.0"
LABEL description="Spatial Platform Localization Service - Production Runtime"

# Security: Create non-root user matching API Gateway pattern
RUN groupadd --gid 1000 spatial \
    && useradd --uid 1000 --gid spatial --shell /bin/false --no-create-home spatial

# Install runtime dependencies and gosu for privilege dropping
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gosu \
    libopencv-dev \
    libeigen3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives \
    && rm -rf /tmp/* /var/tmp/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Enhanced environment configuration
ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app
ENV PYTHONIOENCODING=utf-8

# Set working directory
WORKDIR /app

# Copy application with proper ownership
COPY --chown=spatial:spatial localization_service/ /app/
COPY --chown=spatial:spatial infrastructure/observability/ /app/infrastructure/observability/
COPY --chown=root:root infrastructure/docker/scripts/wait-for-it.sh /usr/local/bin/
COPY --chown=root:root infrastructure/docker/localization/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/wait-for-it.sh /docker-entrypoint.sh

# Create enterprise directory structure with proper permissions
RUN mkdir -p /app/logs /app/temp /app/cache /app/vocab /var/log/spatial/localization \
    && chown -R spatial:spatial /app /var/log/spatial \
    && chmod 755 /app \
    && chmod 755 /app/logs /app/temp /app/cache /app/vocab /var/log/spatial /var/log/spatial/localization

# Enhanced health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose port
EXPOSE 8080

# Use entrypoint for permission handling
ENTRYPOINT ["/docker-entrypoint.sh"]

# Production-optimized command with enhanced settings
CMD ["uvicorn", "app:app", \
     "--host", "0.0.0.0", \
     "--port", "8080", \
     "--workers", "2", \
     "--loop", "uvloop", \
     "--access-log", \
     "--log-config", "/app/logging.json"]