#!/usr/bin/env bash

# Spatial Platform - Health Check Phase
# Extracted from deploy.sh as part of PROJECT_STANDARDS.md compliance
# Version: 1.0.0

# Phase 7: Enterprise health validation and performance monitoring
phase_health_check() {
    print_info "=== Phase 7: Enterprise Health Validation & Performance Monitoring ==="
    CURRENT_PHASE="HEALTH_CHECK"
    save_checkpoint "$CURRENT_PHASE" "started"
    
    print_info "Allowing services to stabilize..."
    sleep 30
    
    echo ""
    echo "=== 📊 Enterprise Deployment Status ==="
    echo ""
    
    # Enhanced container status display
    if docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null; then
        echo ""
    else
        print_warning "Docker-compose ps failed - using fallback status check"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep spatial || echo "No spatial containers found"
        echo ""
    fi
    
    # Enterprise safeguards integration
    if [ -x "$ENTERPRISE_SAFEGUARDS_SCRIPT" ]; then
        print_info "Running enterprise safeguards health validation..."
        
        # Data integrity validation for critical services
        for critical_service in postgres redis minio; do
            "$ENTERPRISE_SAFEGUARDS_SCRIPT" integrity "$critical_service" >/dev/null 2>&1 || \
            print_warning "Data integrity check failed for $critical_service"
        done
        
        # Security scanning for critical services
        for critical_service in postgres redis nakama gateway; do
            "$ENTERPRISE_SAFEGUARDS_SCRIPT" security "$critical_service" >/dev/null 2>&1 || \
            print_warning "Security scan issues detected for $critical_service"
        done
        
        print_status "Enterprise safeguards validation completed"
    fi
    
    # Comprehensive health check
    print_info "Performing comprehensive health validation..."
    
    local healthy_services=0
    local failed_services=0
    local total_services=0
    local service_status_details=""
    
    # Check all services
    for service in $ALL_SERVICES; do
        total_services=$((total_services + 1))
        
        if is_service_running "$service"; then
            healthy_services=$((healthy_services + 1))
            service_status_details="$service_status_details $service:HEALTHY"
        else
            failed_services=$((failed_services + 1))
            service_status_details="$service_status_details $service:FAILED"
        fi
    done
    
    # Performance endpoint testing
    print_info "Testing service endpoints with performance validation..."
    
    local endpoint_tests=0
    local endpoint_passes=0
    
    for threshold_config in $PERFORMANCE_THRESHOLDS; do
        local service port endpoint max_time
        service=$(echo "$threshold_config" | cut -d':' -f1)
        port=$(echo "$threshold_config" | cut -d':' -f2)
        endpoint=$(echo "$threshold_config" | cut -d':' -f3)
        max_time=$(echo "$threshold_config" | cut -d':' -f4)
        
        endpoint_tests=$((endpoint_tests + 1))
        
        local start_time end_time response_time
        # Fix arithmetic overflow - use seconds instead of nanoseconds
        start_time=$(date +%s)
        
        if curl -sf --max-time $((max_time / 1000 + 1)) "http://localhost:$port$endpoint" >/dev/null 2>&1; then
            end_time=$(date +%s)
            response_time=$(((end_time - start_time) * 1000))  # Convert to milliseconds safely
            
            if [ "$response_time" -le "$max_time" ]; then
                print_status "$service endpoint: ${response_time}ms (< ${max_time}ms)"
                endpoint_passes=$((endpoint_passes + 1))
            else
                print_warning "$service endpoint: ${response_time}ms (> ${max_time}ms threshold)"
                PERFORMANCE_ISSUES="$PERFORMANCE_ISSUES Slow_Response:$service:${response_time}ms"
            fi
        else
            print_warning "$service endpoint: Not accessible"
        fi
    done
    
    # Internal service endpoint testing (via docker network)
    if [ -n "${INTERNAL_PERFORMANCE_THRESHOLDS:-}" ]; then
        print_info "Testing internal service endpoints..."
        
        for threshold_config in $INTERNAL_PERFORMANCE_THRESHOLDS; do
            local service port endpoint max_time
            service=$(echo "$threshold_config" | cut -d':' -f1)
            port=$(echo "$threshold_config" | cut -d':' -f2)
            endpoint=$(echo "$threshold_config" | cut -d':' -f3)
            max_time=$(echo "$threshold_config" | cut -d':' -f4)
            
            endpoint_tests=$((endpoint_tests + 1))
            
            local start_time end_time response_time
            start_time=$(date +%s)
            
            # Use docker-compose exec to test internal service endpoints
            if docker-compose exec -T "$service" curl -sf --max-time $((max_time / 1000 + 1)) "http://localhost:$port$endpoint" >/dev/null 2>&1; then
                end_time=$(date +%s)
                response_time=$(((end_time - start_time) * 1000))
                
                if [ "$response_time" -le "$max_time" ]; then
                    print_status "$service internal endpoint: ${response_time}ms (< ${max_time}ms)"
                    endpoint_passes=$((endpoint_passes + 1))
                else
                    print_warning "$service internal endpoint: ${response_time}ms (> ${max_time}ms threshold)"
                    PERFORMANCE_ISSUES="$PERFORMANCE_ISSUES Slow_Internal_Response:$service:${response_time}ms"
                fi
            else
                print_warning "$service internal endpoint: Not accessible"
            fi
        done
    fi
    
    # Health assessment
    echo ""
    print_info "=== 🏥 Health Assessment Summary ==="
    
    local health_percentage=$((healthy_services * 100 / total_services))
    local endpoint_percentage=0
    
    if [ $endpoint_tests -gt 0 ]; then
        endpoint_percentage=$((endpoint_passes * 100 / endpoint_tests))
    fi
    
    echo "Services: $healthy_services/$total_services running ($health_percentage%)"
    echo "Endpoints: $endpoint_passes/$endpoint_tests responding ($endpoint_percentage%)"
    echo "Failed Services: $failed_services"
    
    if [ -n "$FAILED_SERVICES" ]; then
        echo "Failed Service List:$FAILED_SERVICES"
    fi
    
    if [ -n "$PERFORMANCE_ISSUES" ]; then
        echo "Performance Issues:$PERFORMANCE_ISSUES"
    fi
    
    # Determine deployment state
    if [ $health_percentage -ge 90 ] && [ $endpoint_percentage -ge 80 ]; then
        DEPLOYMENT_STATE="excellent"
        print_status "Enterprise deployment: EXCELLENT (≥90% services, ≥80% endpoints)"
    elif [ $health_percentage -ge 70 ] && [ $endpoint_percentage -ge 60 ]; then
        DEPLOYMENT_STATE="good"
        print_status "Enterprise deployment: GOOD (≥70% services, ≥60% endpoints)"
    elif [ $health_percentage -ge 50 ]; then
        DEPLOYMENT_STATE="degraded"
        print_warning "Enterprise deployment: DEGRADED (≥50% services running)"
    else
        DEPLOYMENT_STATE="failed"
        print_error "Enterprise deployment: FAILED (<50% services running)"
    fi
    
    save_checkpoint "$CURRENT_PHASE" "completed"
}