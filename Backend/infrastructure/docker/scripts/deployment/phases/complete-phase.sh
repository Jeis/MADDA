#!/usr/bin/env bash

# Spatial Platform - Complete Phase
# Extracted from deploy.sh as part of PROJECT_STANDARDS.md compliance
# Version: 1.0.0

# Phase 8: Enterprise deployment complete summary and final reporting
phase_complete() {
    print_info "=== Phase 8: Enterprise Deployment Complete ==="
    CURRENT_PHASE="COMPLETE"
    save_checkpoint "$CURRENT_PHASE" "completed"
    
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    local hours=$((total_duration / 3600))
    local minutes=$(((total_duration % 3600) / 60))
    local seconds=$((total_duration % 60))
    
    echo ""
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${CYAN}🎉 ENTERPRISE DEPLOYMENT COMPLETE${NC}"
    echo -e "${PURPLE}================================================================${NC}"
    echo ""
    
    # Deployment metrics
    echo -e "${BLUE}📊 Deployment Metrics:${NC}"
    if [ $hours -gt 0 ]; then
        echo "   • Duration: ${hours}h ${minutes}m ${seconds}s"
    else
        echo "   • Duration: ${minutes}m ${seconds}s"
    fi
    echo "   • Deployment State: $DEPLOYMENT_STATE"
    echo "   • Failed Services: $(echo "$FAILED_SERVICES" | wc -w | tr -d ' ')"
    echo "   • Performance Issues: $(echo "$PERFORMANCE_ISSUES" | wc -w | tr -d ' ')"
    echo "   • Security Issues: $(echo "$SECURITY_ISSUES" | wc -w | tr -d ' ')"
    echo ""
    
    # Access endpoints
    echo -e "${GREEN}🌐 ACCESS ENDPOINTS:${NC}"
    echo ""
    echo -e "${CYAN}Core Services:${NC}"
    echo "   • API Gateway:        http://localhost:8000"
    echo "   • Localization:       http://localhost:8081/health (debug) | http://localhost:8081/healthz (production)"
    echo "   • Cloud Anchors:      http://localhost:9004/health (debug) | http://localhost:9004/healthz (production)"
    echo "   • Nakama Console:     http://localhost:7351"
    echo ""
    
    echo -e "${CYAN}Monitoring & Observability:${NC}"
    echo "   • Grafana Dashboard:  http://localhost:3000 (admin/${GRAFANA_ADMIN_PASSWORD:-admin123})"
    echo "   • Prometheus:         http://localhost:9090"
    echo "   • Jaeger Tracing:     http://localhost:16686"
    echo "   • Loki Logs:          http://localhost:3100"
    echo ""
    
    echo -e "${CYAN}Infrastructure:${NC}"
    echo "   • MinIO Console:      http://localhost:9001 (${MINIO_ROOT_USER:-minioadmin}/${MINIO_ROOT_PASSWORD:-minioadmin123})"
    echo "   • Redis Metrics:      http://localhost:9121/metrics"
    echo ""
    
    echo -e "${CYAN}Enterprise Management:${NC}"
    if [ -x "$ENTERPRISE_SAFEGUARDS_SCRIPT" ]; then
        echo "   • Performance Monitor: $0 --monitor-performance"
        echo "   • Security Audit:     $0 --security-audit"  
        echo "   • Integrity Check:    $0 --data-integrity"
        echo "   • Rollback Management: $0 --rollback-list"
    fi
    if [ -x "$IMAGE_MANAGER_SCRIPT" ]; then
        echo "   • Image Management:   ./infrastructure/docker/scripts/image-manager.sh help"
    fi
    if [ -x "$COMPREHENSIVE_COVERAGE_SCRIPT" ]; then
        echo "   • Coverage Report:    ./infrastructure/docker/scripts/comprehensive-image-coverage.sh generate"
    fi
    echo ""
    
    # Management commands
    echo -e "${BLUE}🔧 MANAGEMENT COMMANDS:${NC}"
    echo ""
    echo -e "${YELLOW}Service Management:${NC}"
    echo "   • Health Check:       make health"
    echo "   • View Logs:          make logs"
    echo "   • Service Logs:       make logs-service SERVICE=gateway"
    echo "   • Service Shell:      make shell SERVICE=gateway"
    echo "   • Stop All:           make stop"
    echo ""
    
    echo -e "${YELLOW}Monitoring:${NC}"
    echo "   • Resource Usage:     docker stats"
    echo "   • Container Status:   docker-compose ps"
    echo "   • Performance Check:  curl -s http://localhost:9090/api/v1/query"
    echo ""
    
    echo -e "${YELLOW}Deployment Management:${NC}"
    echo "   • Resume:             $0 --resume"
    echo "   • Status:             $0 --status"
    echo "   • Reset State:        $0 --reset"
    echo ""
    
    # Recommendations based on deployment state
    case "$DEPLOYMENT_STATE" in
        excellent)
            echo -e "${GREEN}🎯 DEPLOYMENT EXCELLENT:${NC}"
            echo "   • All systems operational and performing within thresholds"
            echo "   • Ready for production workloads"
            echo "   • Consider setting up automated monitoring alerts"
            ;;
        good)
            echo -e "${YELLOW}📋 DEPLOYMENT GOOD:${NC}"
            echo "   • Most systems operational with acceptable performance"
            echo "   • Monitor any performance warnings"
            echo "   • Consider investigating non-responsive endpoints"
            ;;
        degraded)
            echo -e "${YELLOW}⚠️  DEPLOYMENT DEGRADED:${NC}"
            echo "   • Core functionality available but some services failed"
            echo "   • Check failed services: $FAILED_SERVICES"
            echo "   • Review deployment logs: $ERROR_LOG_FILE"
            ;;
        failed)
            echo -e "${RED}❌ DEPLOYMENT FAILED:${NC}"
            echo "   • Critical services are not running"
            echo "   • Investigation required before production use"
            echo "   • Check logs: $ERROR_LOG_FILE"
            ;;
    esac
    
    echo ""
    print_status "Enterprise deployment summary complete!"
    print_info "State files saved in: $STATE_DIR"
}