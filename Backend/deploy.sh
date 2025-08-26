#!/usr/bin/env bash

# Spatial Platform - Enterprise Deployment Script (Modularized)
# Version: 1.0.0 - Modularized for PROJECT_STANDARDS.md compliance
# Following PROJECT_STANDARDS.md requirements with comprehensive automation
# Smart Resume + Full Build Management + Enterprise Validation + Error Recovery

set -euo pipefail

# Force bash for consistent behavior across environments
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

# Colors will be loaded from logging.sh module

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
readonly ENV_FILE="$PROJECT_ROOT/.env"
readonly ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
readonly MAKEFILE="$PROJECT_ROOT/Makefile"

# State Management
readonly STATE_DIR="$PROJECT_ROOT/.deployment-state"
readonly CHECKPOINT_FILE="$STATE_DIR/checkpoint.txt"
readonly BUILD_STATUS_FILE="$STATE_DIR/build-status.txt"
readonly SERVICE_STATUS_FILE="$STATE_DIR/service-status.txt"
readonly ERROR_LOG_FILE="$STATE_DIR/deployment.log"
readonly PERFORMANCE_LOG_FILE="$STATE_DIR/performance.log"

# Performance thresholds (PROJECT_STANDARDS.md compliant) - COMPLETE COVERAGE
# Format: service:external_port:endpoint:max_response_time_ms
# Note: mapping-processor is internal-only service, monitored via docker network
readonly PERFORMANCE_THRESHOLDS="gateway:8000:/healthz:3000 localization:8081:/healthz:2000 nakama:7350:/:5000 prometheus:9090:/-/healthy:2000 grafana:3000:/api/health:3000 cloud-anchor-service:9004:/healthz:2000 vps-engine:9002:/healthz:3000 nginx:80:/healthz:2000 cadvisor:8080:/healthz:5000 jaeger:16686:/:3000 loki:3100:/ready:2000 postgres-exporter:9187:/metrics:2000 minio:9000:/minio/health/live:3000"
readonly INTERNAL_PERFORMANCE_THRESHOLDS="mapping-processor:8080:/healthz:3000"

# Service definitions with optimized build order (light services first, heavy services optimized)
readonly EXTERNAL_SERVICES="postgres redis minio prometheus grafana jaeger cadvisor redis-exporter postgres-exporter"
readonly LIGHT_BUILD_SERVICES="gateway otel-collector loki nakama cloud-anchor-service"
readonly HEAVY_BUILD_SERVICES="localization vps-engine mapping-processor"
readonly INFRASTRUCTURE_BUILD_SERVICES="nginx"  # Services that depend on heavy services
readonly BUILD_SERVICES="$LIGHT_BUILD_SERVICES $HEAVY_BUILD_SERVICES $INFRASTRUCTURE_BUILD_SERVICES"
readonly CORE_INFRASTRUCTURE="postgres redis minio"
readonly APPLICATION_SERVICES="gateway localization nakama cloud-anchor-service vps-engine mapping-processor nginx"
readonly MONITORING_SERVICES="prometheus grafana jaeger cadvisor otel-collector loki redis-exporter postgres-exporter"
readonly ALL_SERVICES="$EXTERNAL_SERVICES $BUILD_SERVICES"

# Build optimization configuration (from log analysis)
readonly MAX_PARALLEL_BUILDS=3
readonly BUILD_CACHE_FILE="$STATE_DIR/build-cache.txt"
readonly TIMING_LOG_FILE="$STATE_DIR/timing.log"

# Heavy services that require special handling
readonly HEAVY_SERVICES="mapping-processor vps-engine localization"

# Deployment phases (Phase 2: Added PACKAGE_VALIDATION for Microsoft-style central management)
readonly PHASES="CLEANUP VALIDATION PACKAGE_VALIDATION IMAGE_BUILD CORE_SERVICES APP_SERVICES MONITORING HEALTH_CHECK COMPLETE"

# External script paths
readonly IMAGE_MANAGER_SCRIPT="$PROJECT_ROOT/infrastructure/docker/scripts/image-manager.sh"
readonly COMPREHENSIVE_COVERAGE_SCRIPT="$PROJECT_ROOT/infrastructure/docker/scripts/comprehensive-image-coverage.sh"
readonly ENTERPRISE_SAFEGUARDS_SCRIPT="$PROJECT_ROOT/infrastructure/docker/scripts/enterprise-safeguards.sh"

# Global state
START_TIME=$(date +%s)
CURRENT_PHASE=""
DEPLOYMENT_STATE="initializing"
FAILED_SERVICES=""
PERFORMANCE_ISSUES=""
SECURITY_ISSUES=""

# =================== MODULE LOADING ===================

# Library directory
readonly LIB_DIR="$SCRIPT_DIR/infrastructure/docker/scripts/deployment/lib"
readonly PHASES_DIR="$SCRIPT_DIR/infrastructure/docker/scripts/deployment/phases"

# Source all library modules in dependency order
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timing.sh" 
source "$LIB_DIR/state-management.sh"
source "$LIB_DIR/validation.sh"
source "$LIB_DIR/service-management.sh"
source "$LIB_DIR/image-management.sh"
source "$LIB_DIR/enterprise-features.sh"
source "$LIB_DIR/documentation.sh"
source "$LIB_DIR/deployment-orchestrator.sh"

# Source all phase modules
source "$PHASES_DIR/cleanup-phase.sh"
source "$PHASES_DIR/validation-phase.sh"
source "$PHASES_DIR/package-validation-phase.sh"  # Phase 2: Microsoft-style package management
source "$PHASES_DIR/image-build-phase.sh"
source "$PHASES_DIR/core-services-phase.sh"
source "$PHASES_DIR/app-services-phase.sh"
source "$PHASES_DIR/monitoring-phase.sh"
source "$PHASES_DIR/health-check-phase.sh"
source "$PHASES_DIR/complete-phase.sh"

# =================== STARTUP BANNER ===================
echo -e "${BLUE}🚀 Spatial Platform - Enterprise Deployment v1.0${NC}"
echo -e "${PURPLE}================================================================${NC}"
echo -e "${CYAN}Modularized | Smart Resume | Comprehensive Build | Error Recovery${NC}"
echo -e "${GREEN}Following PROJECT_STANDARDS.md Enterprise Requirements${NC}"
echo ""

# =================== MISSING UTILITY FUNCTIONS ===================

# Move get_build_complexity from old script to timing.sh if not already there
if ! command -v get_build_complexity >/dev/null 2>&1; then
get_build_complexity() {
    local service="$1"
    case "$service" in
        "mapping-processor") echo "very_heavy:15:4.79GB:colmap,vtk,opencv" ;;
        "localization") echo "heavy:12:3.17GB:opencv,eigen" ;;
        "vps-engine") echo "medium:5:2.39GB:multistage" ;;
        "cloud-anchor-service") echo "light:3:966MB:python" ;;
        "gateway") echo "light:2:446MB:fastapi" ;;
        "nginx") echo "minimal:1:195MB:config" ;;
        "nakama") echo "light:2:398MB:go" ;;
        "otel-collector") echo "light:1:414MB:config" ;;
        "loki") echo "minimal:1:157MB:config" ;;
        *) echo "light:2:100MB:basic" ;;
    esac
}
fi

# =================== MAIN EXECUTION ===================

# Main entry point - delegate to orchestrator
main() {
    # Call the main orchestrator function from deployment-orchestrator.sh
    main_orchestrator "$@"
}

# Execute with all provided arguments
main "$@"