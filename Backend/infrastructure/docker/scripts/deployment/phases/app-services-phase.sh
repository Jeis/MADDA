#!/usr/bin/env bash

# Spatial Platform - Application Services Phase
# Extracted from deploy.sh as part of PROJECT_STANDARDS.md compliance
# Version: 1.0.0

# Phase 5: Application services deployment
phase_app_services() {
    print_info "=== Phase 5: Application Services Deployment ==="
    CURRENT_PHASE="APP_SERVICES"
    save_checkpoint "$CURRENT_PHASE" "started"
    
    # Deploy application services in dependency order (nginx handled by Docker Compose dependencies)
    local app_deployment_order="gateway nakama localization cloud-anchor-service vps-engine mapping-processor nginx"
    
    for service in $app_deployment_order; do
        deploy_service_enhanced "$service" 3 8
    done
    
    save_checkpoint "$CURRENT_PHASE" "completed"
}