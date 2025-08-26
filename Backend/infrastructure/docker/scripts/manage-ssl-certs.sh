#!/bin/bash
# SSL Certificate Management Script for Spatial Platform
# Handles both development (self-signed) and production (Let's Encrypt) certificates

set -e

# Configuration
ENVIRONMENT=${ENVIRONMENT:-development}
DOMAIN_NAME=${DOMAIN_NAME:-localhost}
SSL_DIR="/etc/nginx/ssl"
CERTBOT_EMAIL=${CERTBOT_EMAIL:-admin@spatial.local}
CERTBOT_STAGING=${CERTBOT_STAGING:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create SSL directory if it doesn't exist
mkdir -p ${SSL_DIR}

# Function to generate self-signed certificate for development
generate_self_signed_cert() {
    log_info "Generating self-signed certificate for development..."
    
    # Generate private key
    openssl genrsa -out ${SSL_DIR}/privkey.pem 2048
    
    # Create certificate configuration
    cat > ${SSL_DIR}/cert.conf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = San Francisco
O = Spatial Platform Dev
CN = *.${DOMAIN_NAME}

[v3_req]
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN_NAME}
DNS.2 = *.${DOMAIN_NAME}
DNS.3 = localhost
DNS.4 = *.localhost
DNS.5 = monitoring.${DOMAIN_NAME}
DNS.6 = admin.${DOMAIN_NAME}
DNS.7 = api.${DOMAIN_NAME}
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
    
    # Generate certificate
    openssl req -new -x509 -key ${SSL_DIR}/privkey.pem \
        -out ${SSL_DIR}/fullchain.pem -days 365 \
        -config ${SSL_DIR}/cert.conf -extensions v3_req
    
    # Copy for compatibility
    cp ${SSL_DIR}/fullchain.pem ${SSL_DIR}/cert.pem
    
    log_info "Self-signed certificate generated successfully"
}

# Function to setup Let's Encrypt certificates for production
setup_letsencrypt() {
    log_info "Setting up Let's Encrypt certificates for production..."
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        log_info "Installing certbot..."
        apt-get update && apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Determine staging flag
    STAGING_FLAG=""
    if [ "${CERTBOT_STAGING}" = "true" ]; then
        STAGING_FLAG="--staging"
        log_warn "Using Let's Encrypt staging server (certificates won't be trusted)"
    fi
    
    # Request certificate with multiple domains
    certbot certonly \
        --nginx \
        --non-interactive \
        --agree-tos \
        --email ${CERTBOT_EMAIL} \
        ${STAGING_FLAG} \
        -d ${DOMAIN_NAME} \
        -d www.${DOMAIN_NAME} \
        -d api.${DOMAIN_NAME} \
        -d monitoring.${DOMAIN_NAME} \
        -d admin.${DOMAIN_NAME}
    
    # Create symlinks to Let's Encrypt certificates
    ln -sf /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem ${SSL_DIR}/fullchain.pem
    ln -sf /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem ${SSL_DIR}/privkey.pem
    ln -sf /etc/letsencrypt/live/${DOMAIN_NAME}/chain.pem ${SSL_DIR}/chain.pem
    
    # Setup auto-renewal
    setup_auto_renewal
    
    log_info "Let's Encrypt certificates configured successfully"
}

# Function to setup auto-renewal for Let's Encrypt
setup_auto_renewal() {
    log_info "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > /etc/cron.daily/certbot-renew <<EOF
#!/bin/bash
certbot renew --quiet --no-self-upgrade --post-hook "nginx -s reload"
EOF
    
    chmod +x /etc/cron.daily/certbot-renew
    
    log_info "Auto-renewal configured"
}

# Function to create wildcard certificate for production (requires DNS challenge)
create_wildcard_cert() {
    log_info "Creating wildcard certificate..."
    
    certbot certonly \
        --manual \
        --preferred-challenges dns \
        --non-interactive \
        --agree-tos \
        --email ${CERTBOT_EMAIL} \
        -d "*.${DOMAIN_NAME}" \
        -d ${DOMAIN_NAME}
    
    log_warn "Wildcard certificate requires DNS validation. Follow the instructions above."
}

# Function to verify certificate
verify_certificate() {
    log_info "Verifying SSL certificate..."
    
    if [ -f "${SSL_DIR}/fullchain.pem" ] && [ -f "${SSL_DIR}/privkey.pem" ]; then
        # Check certificate validity
        openssl x509 -in ${SSL_DIR}/fullchain.pem -noout -text | grep -A 2 "Validity"
        
        # Check certificate domains
        log_info "Certificate domains:"
        openssl x509 -in ${SSL_DIR}/fullchain.pem -noout -text | grep -A 1 "Subject Alternative Name"
        
        # Check expiration
        EXPIRY=$(openssl x509 -in ${SSL_DIR}/fullchain.pem -noout -enddate | cut -d= -f2)
        log_info "Certificate expires: ${EXPIRY}"
        
        # Check if certificate is valid
        openssl verify -CAfile ${SSL_DIR}/fullchain.pem ${SSL_DIR}/fullchain.pem 2>/dev/null && \
            log_info "Certificate is valid" || \
            log_warn "Certificate is self-signed or not trusted"
    else
        log_error "Certificate files not found!"
        return 1
    fi
}

# Main logic
main() {
    log_info "SSL Certificate Management - Environment: ${ENVIRONMENT}"
    
    case "${ENVIRONMENT}" in
        development)
            if [ ! -f "${SSL_DIR}/fullchain.pem" ] || [ ! -f "${SSL_DIR}/privkey.pem" ]; then
                generate_self_signed_cert
            else
                log_info "SSL certificates already exist"
            fi
            ;;
            
        production)
            if [ "${USE_LETSENCRYPT}" = "true" ]; then
                setup_letsencrypt
            elif [ "${USE_WILDCARD}" = "true" ]; then
                create_wildcard_cert
            else
                log_warn "Production mode but no certificate method specified"
                log_warn "Set USE_LETSENCRYPT=true or USE_WILDCARD=true"
                log_info "Falling back to self-signed certificate"
                generate_self_signed_cert
            fi
            ;;
            
        *)
            log_error "Unknown environment: ${ENVIRONMENT}"
            exit 1
            ;;
    esac
    
    # Verify the certificate
    verify_certificate
    
    # Set proper permissions
    chown -R nginx:nginx ${SSL_DIR}
    chmod 600 ${SSL_DIR}/privkey.pem
    chmod 644 ${SSL_DIR}/fullchain.pem
    
    log_info "SSL certificate setup complete"
}

# Run main function
main "$@"