#!/usr/bin/env bash

# Spatial Platform - Monitoring Phase
# Extracted from deploy.sh as part of PROJECT_STANDARDS.md compliance
# Version: 1.0.0

# Phase 6: Monitoring and observability stack deployment
phase_monitoring() {
    print_info "=== Phase 6: Monitoring & Observability Stack ==="
    CURRENT_PHASE="MONITORING"
    save_checkpoint "$CURRENT_PHASE" "started"
    
    # Deploy monitoring services in order
    local monitoring_order="prometheus loki otel-collector grafana jaeger cadvisor redis-exporter postgres-exporter"
    
    for service in $monitoring_order; do
        deploy_service_enhanced "$service" 2 5
    done
    
    # Verify monitoring endpoints
    print_info "Verifying monitoring endpoints..."
    sleep 10
    
    local monitoring_endpoints="http://localhost:9090/-/healthy http://localhost:3000/api/health http://localhost:16686/ http://localhost:3100/ready"
    
    for endpoint in $monitoring_endpoints; do
        local service_name
        service_name=$(echo "$endpoint" | sed 's|http://localhost:[0-9]*||' | sed 's|/.*||')
        
        if curl -sf --max-time 3 "$endpoint" >/dev/null 2>&1; then
            print_status "Monitoring endpoint verified: $endpoint"
        else
            print_info "Monitoring endpoint not yet ready: $endpoint"
        fi
    done
    
    save_checkpoint "$CURRENT_PHASE" "completed"
}