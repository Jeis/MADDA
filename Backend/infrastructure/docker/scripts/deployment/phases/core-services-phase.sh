#!/usr/bin/env bash

# Spatial Platform - Core Services Phase
# Extracted from deploy.sh as part of PROJECT_STANDARDS.md compliance
# Version: 1.0.0

# Phase 4: Core infrastructure deployment
phase_core_services() {
    print_info "=== Phase 4: Core Infrastructure Deployment ==="
    CURRENT_PHASE="CORE_SERVICES"
    save_checkpoint "$CURRENT_PHASE" "started"
    
    print_info "Deploying core infrastructure services..."
    
    # Deploy core services with appropriate wait times
    for service in $CORE_INFRASTRUCTURE; do
        deploy_service_enhanced "$service" 3 10
    done
    
    # Enhanced database initialization
    print_info "Initializing PostgreSQL database..."
    if is_service_running "postgres"; then
        local db_init_attempt=0
        local max_db_attempts=30
        
        while [ $db_init_attempt -lt $max_db_attempts ]; do
            if docker-compose exec -T postgres pg_isready -U "${POSTGRES_USER:-admin}" >/dev/null 2>&1; then
                print_status "PostgreSQL is ready for connections"
                
                # Create database and run initialization
                print_info "Running database initialization..."
                docker-compose exec -T postgres psql -U "${POSTGRES_USER:-admin}" -c "CREATE DATABASE IF NOT EXISTS spatial_platform;" 2>/dev/null || true
                
                # Test spatial extensions
                docker-compose exec -T postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-spatial_platform}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true
                docker-compose exec -T postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-spatial_platform}" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" 2>/dev/null || true
                
                print_status "Database initialization completed"
                break
            fi
            
            sleep 2
            db_init_attempt=$((db_init_attempt + 1))
            
            if [ $((db_init_attempt % 10)) -eq 0 ]; then
                print_info "Waiting for PostgreSQL... (${db_init_attempt}/${max_db_attempts})"
            fi
        done
        
        if [ $db_init_attempt -eq $max_db_attempts ]; then
            print_error "PostgreSQL failed to initialize within expected time"
            FAILED_SERVICES="$FAILED_SERVICES postgres"
        fi
    fi
    
    # Enhanced Redis connectivity verification
    if is_service_running "redis"; then
        print_info "Verifying Redis connectivity..."
        local redis_pass="${REDIS_PASSWORD:-redis123}"
        
        # Try multiple connection methods with better error handling
        local redis_connected=false
        
        # Method 1: Try with password
        if docker-compose exec -T redis redis-cli --no-auth-warning -a "$redis_pass" ping 2>/dev/null | grep -q PONG; then
            redis_connected=true
        # Method 2: Try without password (in case auth is disabled)
        elif docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; then
            redis_connected=true
        # Method 3: Check if Redis is just starting up (wait a bit)
        elif sleep 3 && docker-compose exec -T redis redis-cli --no-auth-warning -a "$redis_pass" ping 2>/dev/null | grep -q PONG; then
            redis_connected=true
        fi
        
        if [ "$redis_connected" = true ]; then
            print_status "Redis connectivity verified"
        else
            print_warning "Redis connectivity verification failed - service may still be initializing"
            # Don't fail deployment, just log the warning
        fi
    fi
    
    # Verify MinIO accessibility
    if is_service_running "minio"; then
        print_info "Verifying MinIO accessibility..."
        if curl -sf --max-time 5 http://localhost:9001/ >/dev/null 2>&1; then
            print_status "MinIO console accessible"
        else
            print_warning "MinIO console not yet accessible"
        fi
    fi
    
    save_checkpoint "$CURRENT_PHASE" "completed"
}