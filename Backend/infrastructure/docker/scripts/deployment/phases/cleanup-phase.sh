#!/usr/bin/env bash

# Spatial Platform - Cleanup Phase
# Extracted from deploy.sh as part of PROJECT_STANDARDS.md compliance
# Version: 1.0.0

# Phase 1: Enterprise cleanup of existing containers and resources
phase_cleanup() {
    print_info "=== Phase 1: Enterprise Cleanup ==="
    CURRENT_PHASE="CLEANUP"
    save_checkpoint "$CURRENT_PHASE" "started"
    
    print_info "Performing intelligent cleanup..."
    
    # Check what needs cleaning
    local spatial_containers
    spatial_containers=$(docker ps -a --filter "name=spatial-" --format "{{.Names}}" | wc -l | tr -d ' ')
    
    if [ "$spatial_containers" -eq 0 ]; then
        print_status "No spatial containers found - cleanup not needed"
    else
        print_info "Found $spatial_containers spatial containers - performing cleanup"
        
        # Graceful shutdown of running containers
        print_info "Gracefully stopping running containers..."
        docker-compose down --remove-orphans >/dev/null 2>&1 || true
        
        # Remove any lingering spatial containers
        docker ps -a --filter "name=spatial-" --format "{{.Names}}" | xargs -r docker rm -f >/dev/null 2>&1 || true
        
        print_status "Cleanup completed successfully"
    fi
    
    save_checkpoint "$CURRENT_PHASE" "completed"
}