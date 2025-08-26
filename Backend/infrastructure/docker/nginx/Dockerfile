# Enterprise nginx with TLS and security - Multi-stage build
# OPTIMIZED VERSION - Fixes terminal freezing issues

# Stage 1: Build environment
FROM nginx:1.27-alpine AS builder

LABEL maintainer="platform@spatialvr.com"
LABEL version="2.1.0"
LABEL description="Spatial Platform nginx - Enterprise Grade with TLS and Security Hardening (Optimized)"

# Install build dependencies
RUN apk add --no-cache \
    openssl \
    apache2-utils

# Pre-generate DH parameters to prevent blocking during runtime
RUN openssl dhparam -out /tmp/dhparam.pem 2048

# Copy certificate generation script for runtime execution
COPY infrastructure/docker/nginx/generate-certificates.sh /usr/local/bin/generate-certificates.sh
RUN chmod +x /usr/local/bin/generate-certificates.sh

# Pre-create SSL directory structure
RUN mkdir -p /etc/nginx/ssl

# Stage 2: Runtime environment
FROM nginx:1.27-alpine

# Install runtime dependencies only
RUN apk add --no-cache \
    openssl \
    certbot \
    certbot-nginx \
    curl \
    apache2-utils \
    su-exec \
    && rm -rf /var/cache/apk/*

# Create nginx user if not exists and set permissions
RUN addgroup -g 101 -S nginx 2>/dev/null || true \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx 2>/dev/null || true

# Create required directories with proper permissions
RUN mkdir -p \
    /var/www/certbot \
    /var/www/html \
    /var/www/static \
    /etc/nginx/ssl \
    /var/cache/nginx/static \
    /etc/nginx/conf.d \
    /var/log/nginx \
    /var/run \
    && chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && chown -R nginx:nginx /var/www/certbot \
    && chown -R nginx:nginx /var/www/html \
    && chown -R nginx:nginx /var/www/static \
    && chmod 755 /var/log/nginx \
    && chmod 755 /var/www/html \
    && chmod 755 /var/www/static \
    && touch /var/log/nginx/error.log /var/log/nginx/access.log \
    && chown nginx:nginx /var/log/nginx/*.log \
    && chmod 644 /var/log/nginx/*.log

# Copy pre-generated DH parameters from builder stage
COPY --from=builder /tmp/dhparam.pem /etc/nginx/ssl/dhparam.pem

# Copy certificate generation script from first stage
COPY --from=builder /usr/local/bin/generate-certificates.sh /usr/local/bin/generate-certificates.sh
RUN chmod +x /usr/local/bin/generate-certificates.sh

# Copy configuration files
COPY --chown=nginx:nginx infrastructure/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx infrastructure/docker/nginx/conf.d/ /etc/nginx/conf.d/
COPY --chown=nginx:nginx infrastructure/docker/nginx/ssl-config.conf /etc/nginx/ssl-config.conf

# Set proper permissions for enterprise certificates
RUN chmod 755 /etc/nginx/ssl \
    && chmod 644 /etc/nginx/ssl/*.crt /etc/nginx/ssl/dhparam.pem 2>/dev/null || true \
    && chmod 600 /etc/nginx/ssl/*.key 2>/dev/null || true \
    && chown -R nginx:nginx /etc/nginx/ssl

# Create empty htpasswd files - will be populated from secrets at runtime
RUN touch /etc/nginx/.htpasswd \
    && touch /etc/nginx/.htpasswd-admin \
    && chmod 640 /etc/nginx/.htpasswd* \
    && chown nginx:nginx /etc/nginx/.htpasswd*

# Copy OPTIMIZED entrypoint script
COPY --chown=root:root infrastructure/docker/nginx/entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

# Security hardening
RUN rm -rf /usr/share/nginx/html/* \
    && echo "nginx:x:101:101:nginx:/var/cache/nginx:/sbin/nologin" > /etc/passwd \
    && echo "nginx:x:101:" > /etc/group

# Health check with optimized endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/healthz || exit 1

# Note: nginx runs as root in container for Docker logging compatibility

EXPOSE 80 443

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
