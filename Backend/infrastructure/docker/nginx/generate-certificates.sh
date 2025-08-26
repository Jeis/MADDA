#!/bin/bash
set -e

# Enterprise Certificate Generation Script
# Supports development, staging, and production environments

CERT_DIR="/etc/nginx/ssl"
ENVIRONMENT=${ENVIRONMENT:-development}
DOMAIN_NAME=${DOMAIN_NAME:-localhost}

echo "🔐 Generating SSL certificates for environment: $ENVIRONMENT"
echo "   Domain: $DOMAIN_NAME"

# Create certificate directory
mkdir -p "$CERT_DIR"

case "$ENVIRONMENT" in
    "development"|"dev")
        echo "📋 Development Mode: Generating self-signed certificates"
        
        # Generate wildcard certificate for localhost and subdomains
        # Generate production-grade self-signed certificate for localhost
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
            -keyout "$CERT_DIR/localhost.key" \
            -out "$CERT_DIR/localhost.crt" \
            -subj "/C=US/ST=California/L=San Francisco/O=Spatial Platform/OU=Enterprise/CN=localhost" \
            -addext "subjectAltName=DNS:localhost,DNS:*.localhost,DNS:monitoring.localhost,DNS:admin.localhost,DNS:api.localhost,DNS:gateway.localhost,IP:127.0.0.1,IP:::1"

        # Create unified development certificate
        cp "$CERT_DIR/localhost.crt" "$CERT_DIR/wildcard-dev.crt"
        cp "$CERT_DIR/localhost.key" "$CERT_DIR/wildcard-dev.key"

        # Generate DH parameters for security
        openssl dhparam -out "$CERT_DIR/dhparam.pem" 2048

        echo "✅ Development certificates generated"
        ;;

    "staging")
        echo "🧪 Staging Mode: Generating staging certificates"
        
        # Generate staging certificates (can be self-signed or Let's Encrypt)
        openssl req -x509 -nodes -days 90 -newkey rsa:4096 \
            -keyout "$CERT_DIR/staging.${DOMAIN_NAME}.key" \
            -out "$CERT_DIR/staging.${DOMAIN_NAME}.crt" \
            -subj "/C=US/ST=California/L=San Francisco/O=Spatial Platform/OU=Staging/CN=staging.${DOMAIN_NAME}"

        # Create symlinks for easier management
        ln -sf "staging.${DOMAIN_NAME}.crt" "$CERT_DIR/wildcard-dev.crt"
        ln -sf "staging.${DOMAIN_NAME}.key" "$CERT_DIR/wildcard-dev.key"

        openssl dhparam -out "$CERT_DIR/dhparam.pem" 2048

        echo "✅ Staging certificates generated"
        ;;

    "production"|"prod")
        echo "🏭 Production Mode: Enterprise certificate configuration"
        
        # For localhost in production mode, use production-grade self-signed
        if [ "$DOMAIN_NAME" = "localhost" ]; then
            echo "📋 Generating production-grade self-signed certificates for localhost"
            
            openssl req -x509 -nodes -days 90 -newkey rsa:4096 \
                -keyout "$CERT_DIR/localhost.key" \
                -out "$CERT_DIR/localhost.crt" \
                -subj "/C=US/ST=California/L=San Francisco/O=Spatial Platform/OU=Production/CN=localhost" \
                -addext "subjectAltName=DNS:localhost,DNS:*.localhost,DNS:monitoring.localhost,DNS:admin.localhost,IP:127.0.0.1,IP:::1"
            
            ln -sf "localhost.crt" "$CERT_DIR/main.crt"
            ln -sf "localhost.key" "$CERT_DIR/main.key"
            
            echo "✅ Production-grade localhost certificates generated"
            return
        fi
        
        echo "🏭 Production Mode: Setting up for real domain certificates"
        
        if [ -f "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" ]; then
            echo "📋 Using existing Let's Encrypt certificates"
            
            # Use Let's Encrypt certificates
            ln -sf "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" "$CERT_DIR/${DOMAIN_NAME}.crt"
            ln -sf "/etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem" "$CERT_DIR/${DOMAIN_NAME}.key"
            ln -sf "/etc/letsencrypt/live/${DOMAIN_NAME}/chain.pem" "$CERT_DIR/chain.pem"
            
            # Generate monitoring subdomain certificates if needed
            if [ -f "/etc/letsencrypt/live/monitoring.${DOMAIN_NAME}/fullchain.pem" ]; then
                ln -sf "/etc/letsencrypt/live/monitoring.${DOMAIN_NAME}/fullchain.pem" "$CERT_DIR/monitoring.${DOMAIN_NAME}.crt"
                ln -sf "/etc/letsencrypt/live/monitoring.${DOMAIN_NAME}/privkey.pem" "$CERT_DIR/monitoring.${DOMAIN_NAME}.key"
            fi
            
            if [ -f "/etc/letsencrypt/live/admin.${DOMAIN_NAME}/fullchain.pem" ]; then
                ln -sf "/etc/letsencrypt/live/admin.${DOMAIN_NAME}/fullchain.pem" "$CERT_DIR/admin.${DOMAIN_NAME}.crt"
                ln -sf "/etc/letsencrypt/live/admin.${DOMAIN_NAME}/privkey.pem" "$CERT_DIR/admin.${DOMAIN_NAME}.key"
            fi
            
        else
            echo "⚠️  No Let's Encrypt certificates found. Generating temporary certificates."
            echo "    Run certbot to obtain real certificates for production."
            
            # Generate temporary production certificates
            openssl req -x509 -nodes -days 30 -newkey rsa:4096 \
                -keyout "$CERT_DIR/${DOMAIN_NAME}.key" \
                -out "$CERT_DIR/${DOMAIN_NAME}.crt" \
                -subj "/C=US/ST=California/L=San Francisco/O=Spatial Platform/OU=Production-Temp/CN=${DOMAIN_NAME}" \
                -addext "subjectAltName=DNS:${DOMAIN_NAME},DNS:*.${DOMAIN_NAME}"
        fi

        # Always generate strong DH parameters for production
        if [ ! -f "$CERT_DIR/dhparam.pem" ]; then
            echo "🔒 Generating strong DH parameters (this may take a while)..."
            openssl dhparam -out "$CERT_DIR/dhparam.pem" 4096
        fi

        echo "✅ Production certificate setup complete"
        ;;

    *)
        echo "❌ Unknown environment: $ENVIRONMENT"
        echo "    Supported: development, staging, production"
        exit 1
        ;;
esac

# Set proper permissions
chmod 644 "$CERT_DIR"/*.crt "$CERT_DIR"/*.pem 2>/dev/null || true
chmod 600 "$CERT_DIR"/*.key 2>/dev/null || true
chown -R nginx:nginx "$CERT_DIR" 2>/dev/null || true

echo "🎯 Certificate generation completed for $ENVIRONMENT environment"
echo "📁 Certificates location: $CERT_DIR"

# Display certificate information
if [ -f "$CERT_DIR/localhost.crt" ]; then
    echo "📋 Certificate details:"
    openssl x509 -in "$CERT_DIR/localhost.crt" -text -noout | grep -A1 "Subject:"
    openssl x509 -in "$CERT_DIR/localhost.crt" -text -noout | grep -A1 "DNS:"
fi