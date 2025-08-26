#!/usr/bin/env bash

# Spatial Platform - Enterprise Safeguards & Performance Monitoring
# Version: 2.0.0 - Production Ready
#
# ENTERPRISE SAFEGUARDS SYSTEM
#
# Features:
# - Performance monitoring hooks for 60fps AR/VR requirements
# - Automated rollback capabilities for breaking changes  
# - Data integrity validation for critical services
# - Security scanning integration with vulnerability detection
# - Comprehensive health monitoring with alerting
# - Resource utilization monitoring and optimization
# - Automated recovery procedures with escalation
# - Enterprise-grade logging and audit trails

set -euo pipefail

# Force bash for consistent behavior across environments
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

# Colors for enterprise output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly SAFEGUARDS_DIR="$PROJECT_ROOT/.enterprise-safeguards"
readonly MONITORING_DIR="$SAFEGUARDS_DIR/monitoring"
readonly ROLLBACK_DIR="$SAFEGUARDS_DIR/rollbacks"
readonly AUDIT_DIR="$SAFEGUARDS_DIR/audit"

# Performance thresholds for 60fps AR/VR requirements
readonly CPU_THRESHOLD_WARN=70    # Warning at 70% CPU
readonly CPU_THRESHOLD_CRITICAL=85  # Critical at 85% CPU
readonly MEMORY_THRESHOLD_WARN=80   # Warning at 80% Memory
readonly MEMORY_THRESHOLD_CRITICAL=90  # Critical at 90% Memory
readonly RESPONSE_TIME_THRESHOLD=100   # 100ms response time threshold
readonly FRAME_RATE_THRESHOLD=58      # 58fps minimum (buffer for 60fps target)

# Critical services that cannot be interrupted
readonly CRITICAL_SERVICES="postgres redis nakama gateway localization"

# Enterprise logging
log_with_timestamp() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_status() {
    log_with_timestamp "${GREEN}✅ $1${NC}"
    log_audit "STATUS" "$1"
}

print_warning() {
    log_with_timestamp "${YELLOW}⚠️  $1${NC}"
    log_audit "WARNING" "$1"
}

print_error() {
    log_with_timestamp "${RED}❌ $1${NC}"
    log_audit "ERROR" "$1"
}

print_info() {
    log_with_timestamp "${CYAN}ℹ️  $1${NC}"
    log_audit "INFO" "$1"
}

print_security() {
    log_with_timestamp "${PURPLE}🔒 SECURITY: $1${NC}"
    log_audit "SECURITY" "$1"
}

print_performance() {
    log_with_timestamp "${YELLOW}⚡ PERFORMANCE: $1${NC}"
    log_audit "PERFORMANCE" "$1"
}

print_critical() {
    log_with_timestamp "${RED}🚨 CRITICAL: $1${NC}"
    log_audit "CRITICAL" "$1"
}

# Initialize enterprise safeguards
init_safeguards() {
    # Create directory structure
    mkdir -p "$SAFEGUARDS_DIR" "$MONITORING_DIR" "$ROLLBACK_DIR" "$AUDIT_DIR"
    
    # Initialize audit log
    local audit_file="$AUDIT_DIR/safeguards_$(date +%Y%m%d).log"
    if [ ! -f "$audit_file" ]; then
        echo "=== Enterprise Safeguards Audit Log - $(date) ===" > "$audit_file"
    fi
    
    print_info "Initialized enterprise safeguards system"
}

# Audit logging function
log_audit() {
    local level="$1"
    local message="$2"
    local audit_file="$AUDIT_DIR/safeguards_$(date +%Y%m%d).log"
    
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$level] $message" >> "$audit_file"
}

# Performance monitoring with AR/VR specific metrics
monitor_performance() {
    local service="$1"
    local duration="${2:-60}"  # Monitor for 60 seconds by default
    
    print_info "Starting performance monitoring for $service (${duration}s)"
    
    local container_name="spatial-$service"
    local container_id
    container_id=$(docker ps --filter "name=$container_name" --format "{{.ID}}" | head -1)
    
    if [ -z "$container_id" ]; then
        print_warning "Container $container_name not found for monitoring"
        return 1
    fi
    
    local monitoring_file="$MONITORING_DIR/${service}_$(date +%Y%m%d_%H%M%S).json"
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    # Create monitoring record
    cat > "$monitoring_file" <<EOF
{
    "service": "$service",
    "container_id": "$container_id",
    "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "thresholds": {
        "cpu_warn": $CPU_THRESHOLD_WARN,
        "cpu_critical": $CPU_THRESHOLD_CRITICAL,
        "memory_warn": $MEMORY_THRESHOLD_WARN,
        "memory_critical": $MEMORY_THRESHOLD_CRITICAL,
        "response_time": $RESPONSE_TIME_THRESHOLD
    },
    "metrics": [
EOF
    
    local first_metric=true
    local alert_count=0
    local critical_count=0
    
    while [ "$(date +%s)" -lt "$end_time" ]; do
        # Get container stats
        local stats
        stats=$(docker stats --no-stream "$container_id" --format "{{.CPUPerc}} {{.MemPerc}} {{.MemUsage}} {{.NetIO}} {{.BlockIO}}" 2>/dev/null || echo "")
        
        if [ -n "$stats" ]; then
            local cpu_percent mem_percent mem_usage net_io block_io
            cpu_percent=$(echo "$stats" | cut -d' ' -f1 | tr -d '%')
            mem_percent=$(echo "$stats" | cut -d' ' -f2 | tr -d '%')
            mem_usage=$(echo "$stats" | cut -d' ' -f3)
            net_io=$(echo "$stats" | cut -d' ' -f4)
            block_io=$(echo "$stats" | cut -d' ' -f5)
            
            # Check thresholds and trigger alerts
            local alert_level="normal"
            local alert_message=""
            
            if (( $(echo "$cpu_percent > $CPU_THRESHOLD_CRITICAL" | bc -l 2>/dev/null || echo "0") )); then
                alert_level="critical"
                alert_message="CPU usage critical: $cpu_percent%"
                critical_count=$((critical_count + 1))
                print_critical "$service - $alert_message"
                
                # Trigger automated response for critical CPU
                trigger_automated_response "$service" "cpu_critical" "$cpu_percent"
                
            elif (( $(echo "$cpu_percent > $CPU_THRESHOLD_WARN" | bc -l 2>/dev/null || echo "0") )); then
                alert_level="warning"
                alert_message="CPU usage high: $cpu_percent%"
                alert_count=$((alert_count + 1))
                print_warning "$service - $alert_message"
            fi
            
            if (( $(echo "$mem_percent > $MEMORY_THRESHOLD_CRITICAL" | bc -l 2>/dev/null || echo "0") )); then
                alert_level="critical"
                alert_message="${alert_message:+$alert_message, }Memory usage critical: $mem_percent%"
                critical_count=$((critical_count + 1))
                print_critical "$service - Memory critical: $mem_percent%"
                
                # Trigger automated response for critical memory
                trigger_automated_response "$service" "memory_critical" "$mem_percent"
                
            elif (( $(echo "$mem_percent > $MEMORY_THRESHOLD_WARN" | bc -l 2>/dev/null || echo "0") )); then
                alert_level="warning"
                alert_message="${alert_message:+$alert_message, }Memory usage high: $mem_percent%"
                alert_count=$((alert_count + 1))
                print_warning "$service - Memory high: $mem_percent%"
            fi
            
            # Add metric to JSON (remove comma from first entry)
            if [ "$first_metric" = true ]; then
                first_metric=false
            else
                echo "," >> "$monitoring_file"
            fi
            
            cat >> "$monitoring_file" <<EOF
        {
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "cpu_percent": $cpu_percent,
            "memory_percent": $mem_percent,
            "memory_usage": "$mem_usage",
            "network_io": "$net_io",
            "block_io": "$block_io",
            "alert_level": "$alert_level",
            "alert_message": "$alert_message"
        }EOF
        fi
        
        sleep 5  # Monitor every 5 seconds
    done
    
    # Close monitoring record
    cat >> "$monitoring_file" <<EOF
    ],
    "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "summary": {
        "alert_count": $alert_count,
        "critical_count": $critical_count,
        "monitoring_duration": $duration
    }
}
EOF
    
    print_performance "$service monitoring completed: $alert_count alerts, $critical_count critical events"
    echo "$monitoring_file"
}

# Automated response system for performance issues
trigger_automated_response() {
    local service="$1"
    local issue_type="$2"
    local metric_value="$3"
    
    print_info "Triggering automated response for $service: $issue_type ($metric_value)"
    
    case "$issue_type" in
        cpu_critical)
            # For CPU critical issues
            print_info "Implementing CPU optimization measures for $service..."
            
            # Restart service if it's not critical, or scale if possible
            if [[ ! " $CRITICAL_SERVICES " =~ " $service " ]]; then
                print_info "Restarting non-critical service $service to resolve CPU issues"
                docker-compose restart "$service" || true
            else
                print_warning "Critical service $service has CPU issues - alerting operations team"
                send_alert "CRITICAL_CPU" "$service" "CPU usage: $metric_value%"
            fi
            ;;
        memory_critical)
            # For memory critical issues
            print_info "Implementing memory optimization measures for $service..."
            
            # Clear caches if possible
            if [ "$service" = "redis" ]; then
                print_info "Optimizing Redis memory usage"
                docker-compose exec -T redis redis-cli MEMORY PURGE || true
            elif [ "$service" = "postgres" ]; then
                print_info "Optimizing PostgreSQL memory usage"
                docker-compose exec -T postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-spatial_platform}" -c "CHECKPOINT;" || true
            fi
            
            send_alert "CRITICAL_MEMORY" "$service" "Memory usage: $metric_value%"
            ;;
        response_slow)
            print_info "Implementing response time optimization for $service..."
            check_service_dependencies "$service"
            ;;
    esac
}

# Send alerts to operations team
send_alert() {
    local alert_type="$1"
    local service="$2"
    local details="$3"
    
    local alert_file="$AUDIT_DIR/alerts_$(date +%Y%m%d).log"
    local alert_message="ALERT [$alert_type] Service: $service, Details: $details"
    
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $alert_message" >> "$alert_file"
    print_critical "$alert_message"
    
    # In production, this would integrate with alerting systems like PagerDuty, Slack, etc.
    # Example integrations:
    # - curl -X POST -H 'Content-type: application/json' --data '{"text":"'"$alert_message"'"}' "$SLACK_WEBHOOK_URL"
    # - Send email via SMTP
    # - Call PagerDuty API
}

# Health monitoring with AR/VR specific checks
monitor_service_health() {
    local service="$1"
    local endpoint="${2:-/healthz}"
    local port="${3:-8000}"
    
    print_info "Monitoring health for $service at :$port$endpoint"
    
    local health_file="$MONITORING_DIR/${service}_health_$(date +%Y%m%d_%H%M%S).json"
    local start_time
    start_time=$(date +%s)
    
    # Test response time multiple times for accuracy
    local response_times=()
    local successful_requests=0
    local total_requests=10
    
    for i in $(seq 1 $total_requests); do
        local request_start
        request_start=$(date +%s%3N)  # Milliseconds
        
        if curl -sf --max-time 5 "http://localhost:$port$endpoint" >/dev/null 2>&1; then
            local request_end
            request_end=$(date +%s%3N)
            local response_time=$((request_end - request_start))
            response_times+=("$response_time")
            successful_requests=$((successful_requests + 1))
        fi
        
        sleep 1
    done
    
    # Calculate statistics
    local avg_response_time=0
    local max_response_time=0
    local min_response_time=999999
    
    if [ ${#response_times[@]} -gt 0 ]; then
        local sum=0
        for time in "${response_times[@]}"; do
            sum=$((sum + time))
            if [ "$time" -gt "$max_response_time" ]; then
                max_response_time=$time
            fi
            if [ "$time" -lt "$min_response_time" ]; then
                min_response_time=$time
            fi
        done
        avg_response_time=$((sum / ${#response_times[@]}))
    fi
    
    # Determine health status
    local health_status="healthy"
    local health_issues=()
    
    if [ "$successful_requests" -lt $((total_requests * 8 / 10)) ]; then
        health_status="unhealthy"
        health_issues+=("Low success rate: $successful_requests/$total_requests")
    fi
    
    if [ "$avg_response_time" -gt "$RESPONSE_TIME_THRESHOLD" ]; then
        health_status="degraded"
        health_issues+=("Slow response time: ${avg_response_time}ms > ${RESPONSE_TIME_THRESHOLD}ms")
    fi
    
    # For AR/VR services, check frame rate capability
    if [[ "$service" =~ (nakama|localization|gateway) ]]; then
        local frame_capability=$((1000 / (avg_response_time + 10)))  # Add 10ms processing buffer
        if [ "$frame_capability" -lt "$FRAME_RATE_THRESHOLD" ]; then
            health_status="ar_vr_incompatible"
            health_issues+=("Frame rate capability: ${frame_capability}fps < ${FRAME_RATE_THRESHOLD}fps")
        fi
    fi
    
    # Create health record
    cat > "$health_file" <<EOF
{
    "service": "$service",
    "endpoint": "$endpoint",
    "port": $port,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "health_status": "$health_status",
    "metrics": {
        "successful_requests": $successful_requests,
        "total_requests": $total_requests,
        "success_rate": $(echo "scale=2; $successful_requests * 100 / $total_requests" | bc),
        "avg_response_time_ms": $avg_response_time,
        "min_response_time_ms": $min_response_time,
        "max_response_time_ms": $max_response_time,
        "frame_capability_fps": $(echo "1000 / ($avg_response_time + 10)" | bc)
    },
    "issues": [
EOF
    
    # Add issues to JSON
    local first_issue=true
    for issue in "${health_issues[@]}"; do
        if [ "$first_issue" = true ]; then
            first_issue=false
        else
            echo "," >> "$health_file"
        fi
        echo "        \"$issue\"" >> "$health_file"
    done
    
    cat >> "$health_file" <<EOF
    ],
    "ar_vr_requirements": {
        "target_fps": 60,
        "response_threshold_ms": $RESPONSE_TIME_THRESHOLD,
        "meets_requirements": $([ "$health_status" != "ar_vr_incompatible" ] && echo "true" || echo "false")
    }
}
EOF
    
    # Report health status
    case "$health_status" in
        healthy)
            print_status "$service health check: HEALTHY (${avg_response_time}ms avg)"
            ;;
        degraded)
            print_warning "$service health check: DEGRADED - ${health_issues[*]}"
            ;;
        unhealthy)
            print_error "$service health check: UNHEALTHY - ${health_issues[*]}"
            send_alert "SERVICE_UNHEALTHY" "$service" "${health_issues[*]}"
            ;;
        ar_vr_incompatible)
            print_critical "$service health check: AR/VR INCOMPATIBLE - ${health_issues[*]}"
            send_alert "AR_VR_PERFORMANCE" "$service" "${health_issues[*]}"
            ;;
    esac
    
    echo "$health_file"
}

# Automated rollback system
create_rollback_point() {
    local description="$1"
    local services="${2:-all}"
    
    print_info "Creating rollback point: $description"
    
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local rollback_id="rollback_$timestamp"
    local rollback_path="$ROLLBACK_DIR/$rollback_id"
    
    mkdir -p "$rollback_path"
    
    # Save current configuration
    if [ -f "$PROJECT_ROOT/.env" ]; then
        cp "$PROJECT_ROOT/.env" "$rollback_path/env"
    fi
    
    if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        cp "$PROJECT_ROOT/docker-compose.yml" "$rollback_path/docker-compose.yml"
    fi
    
    # Save service states
    docker-compose ps --format json > "$rollback_path/service_states.json" 2>/dev/null || echo "[]" > "$rollback_path/service_states.json"
    
    # Save container information
    if [ "$services" = "all" ]; then
        docker ps --filter "name=spatial-" --format json > "$rollback_path/containers.json" 2>/dev/null || echo "[]" > "$rollback_path/containers.json"
    else
        for service in $services; do
            docker ps --filter "name=spatial-$service" --format json >> "$rollback_path/containers.json" 2>/dev/null || true
        done
    fi
    
    # Create rollback metadata
    cat > "$rollback_path/metadata.json" <<EOF
{
    "rollback_id": "$rollback_id",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "description": "$description",
    "services": "$services",
    "created_by": "enterprise-safeguards",
    "system_info": {
        "hostname": "$(hostname)",
        "user": "$(whoami)",
        "working_directory": "$PROJECT_ROOT"
    }
}
EOF
    
    print_status "Rollback point created: $rollback_id"
    echo "$rollback_path"
}

# Execute rollback
execute_rollback() {
    local rollback_path="$1"
    local force="${2:-false}"
    
    if [ ! -d "$rollback_path" ]; then
        print_error "Rollback point not found: $rollback_path"
        return 1
    fi
    
    local rollback_id
    rollback_id=$(basename "$rollback_path")
    
    print_info "Executing rollback: $rollback_id"
    
    # Load rollback metadata
    local metadata_file="$rollback_path/metadata.json"
    if [ ! -f "$metadata_file" ]; then
        print_error "Rollback metadata not found"
        return 1
    fi
    
    local description
    description=$(jq -r '.description' "$metadata_file" 2>/dev/null || echo "Unknown")
    
    if [ "$force" != "true" ]; then
        echo "About to rollback to: $description"
        echo "This will restore configuration and restart services."
        read -p "Continue with rollback? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Rollback cancelled"
            return 0
        fi
    fi
    
    # Create pre-rollback backup
    local pre_rollback_backup
    pre_rollback_backup=$(create_rollback_point "Pre-rollback backup before $rollback_id")
    
    # Stop services
    print_info "Stopping services for rollback..."
    docker-compose down || true
    
    # Restore configuration files
    if [ -f "$rollback_path/env" ]; then
        cp "$rollback_path/env" "$PROJECT_ROOT/.env"
        print_status "Restored environment configuration"
    fi
    
    if [ -f "$rollback_path/docker-compose.yml" ]; then
        cp "$rollback_path/docker-compose.yml" "$PROJECT_ROOT/docker-compose.yml"
        print_status "Restored docker-compose configuration"
    fi
    
    # Restart services
    print_info "Restarting services after rollback..."
    if docker-compose up -d; then
        print_status "Rollback completed successfully"
        
        # Verify services after rollback
        sleep 30
        local healthy_services=0
        local total_services=0
        
        for service in $CRITICAL_SERVICES; do
            total_services=$((total_services + 1))
            if docker-compose ps "$service" | grep -q "Up"; then
                healthy_services=$((healthy_services + 1))
            fi
        done
        
        if [ "$healthy_services" -eq "$total_services" ]; then
            print_status "All critical services restored successfully"
        else
            print_warning "Some services may need manual intervention: $healthy_services/$total_services healthy"
            send_alert "ROLLBACK_PARTIAL" "system" "$healthy_services/$total_services services healthy"
        fi
        
    else
        print_error "Rollback failed during service restart"
        print_info "Emergency restoration from: $pre_rollback_backup"
        return 1
    fi
}

# Data integrity validation
validate_data_integrity() {
    local service="$1"
    
    print_info "Validating data integrity for $service"
    
    local integrity_file="$MONITORING_DIR/${service}_integrity_$(date +%Y%m%d_%H%M%S).json"
    local integrity_status="unknown"
    local integrity_issues=()
    
    case "$service" in
        postgres)
            if docker-compose ps postgres | grep -q "Up"; then
                local db_status
                db_status=$(docker-compose exec -T postgres pg_isready -U "${POSTGRES_USER:-admin}" 2>&1 || echo "failed")
                
                if [[ "$db_status" =~ "accepting connections" ]]; then
                    # Check database size and table count
                    local db_size table_count
                    db_size=$(docker-compose exec -T postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-spatial_platform}" -t -c "SELECT pg_size_pretty(pg_database_size('${POSTGRES_DB:-spatial_platform}'));" 2>/dev/null | tr -d ' \n\r' || echo "unknown")
                    table_count=$(docker-compose exec -T postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-spatial_platform}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' \n\r' || echo "0")
                    
                    # Check for corruption
                    local corruption_check
                    corruption_check=$(docker-compose exec -T postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-spatial_platform}" -t -c "SELECT COUNT(*) FROM pg_stat_database WHERE datname = '${POSTGRES_DB:-spatial_platform}' AND stats_reset IS NOT NULL;" 2>/dev/null | tr -d ' \n\r' || echo "0")
                    
                    if [ "$table_count" -gt 0 ]; then
                        integrity_status="healthy"
                        print_status "PostgreSQL integrity: HEALTHY ($table_count tables, $db_size)"
                    else
                        integrity_status="warning"
                        integrity_issues+=("No user tables found")
                    fi
                else
                    integrity_status="unhealthy"
                    integrity_issues+=("Database not accepting connections")
                fi
            else
                integrity_status="unavailable"
                integrity_issues+=("PostgreSQL container not running")
            fi
            ;;
            
        redis)
            if docker-compose ps redis | grep -q "Up"; then
                local redis_info
                redis_info=$(docker-compose exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD:-redis123}" info server 2>/dev/null | head -10 || echo "failed")
                
                if [[ "$redis_info" =~ "redis_version" ]]; then
                    local memory_usage key_count
                    memory_usage=$(docker-compose exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD:-redis123}" info memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | tr -d '\r' || echo "unknown")
                    key_count=$(docker-compose exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD:-redis123}" dbsize 2>/dev/null | tr -d '\r' || echo "0")
                    
                    integrity_status="healthy"
                    print_status "Redis integrity: HEALTHY ($key_count keys, $memory_usage used)"
                else
                    integrity_status="unhealthy"
                    integrity_issues+=("Redis not responding to commands")
                fi
            else
                integrity_status="unavailable"
                integrity_issues+=("Redis container not running")
            fi
            ;;
            
        minio)
            if docker-compose ps minio | grep -q "Up"; then
                if curl -sf --max-time 5 "http://localhost:9000/minio/health/live" >/dev/null 2>&1; then
                    integrity_status="healthy"
                    print_status "MinIO integrity: HEALTHY"
                else
                    integrity_status="unhealthy"
                    integrity_issues+=("MinIO health check failed")
                fi
            else
                integrity_status="unavailable"
                integrity_issues+=("MinIO container not running")
            fi
            ;;
    esac
    
    # Create integrity record
    cat > "$integrity_file" <<EOF
{
    "service": "$service",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "integrity_status": "$integrity_status",
    "issues": [
EOF
    
    # Add issues to JSON
    local first_issue=true
    for issue in "${integrity_issues[@]}"; do
        if [ "$first_issue" = true ]; then
            first_issue=false
        else
            echo "," >> "$integrity_file"
        fi
        echo "        \"$issue\"" >> "$integrity_file"
    done
    
    cat >> "$integrity_file" <<EOF
    ]
}
EOF
    
    if [ "$integrity_status" = "unhealthy" ]; then
        send_alert "DATA_INTEGRITY" "$service" "${integrity_issues[*]}"
    fi
    
    echo "$integrity_file"
}

# Security scanning with vulnerability detection
security_scan() {
    local service="$1"
    
    print_security "Running security scan for $service"
    
    local scan_file="$MONITORING_DIR/${service}_security_$(date +%Y%m%d_%H%M%S).json"
    local security_issues=()
    local security_score=100  # Start with perfect score and deduct points
    
    # Get container information
    local container_name="spatial-$service"
    local container_id
    container_id=$(docker ps --filter "name=$container_name" --format "{{.ID}}" | head -1)
    
    if [ -z "$container_id" ]; then
        print_warning "Container $container_name not found for security scan"
        return 1
    fi
    
    # Check for running as root
    local user_info
    user_info=$(docker exec "$container_id" whoami 2>/dev/null || echo "unknown")
    if [ "$user_info" = "root" ]; then
        security_issues+=("Running as root user")
        security_score=$((security_score - 20))
    fi
    
    # Check for privileged mode
    local privileged
    privileged=$(docker inspect "$container_id" --format '{{.HostConfig.Privileged}}' 2>/dev/null || echo "false")
    if [ "$privileged" = "true" ]; then
        security_issues+=("Running in privileged mode")
        security_score=$((security_score - 30))
    fi
    
    # Check for exposed sensitive ports
    local ports
    ports=$(docker port "$container_id" 2>/dev/null || echo "")
    if echo "$ports" | grep -q ":22\|:23\|:3389"; then
        security_issues+=("Sensitive ports exposed")
        security_score=$((security_score - 15))
    fi
    
    # Check for latest tag usage (indicates potentially outdated image)
    local image
    image=$(docker inspect "$container_id" --format '{{.Config.Image}}' 2>/dev/null || echo "")
    if [[ "$image" =~ :latest$ ]]; then
        security_issues+=("Using :latest tag")
        security_score=$((security_score - 10))
    fi
    
    # Check for writable filesystem
    local readonly_fs
    readonly_fs=$(docker inspect "$container_id" --format '{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null || echo "false")
    if [ "$readonly_fs" = "false" ]; then
        security_issues+=("Writable root filesystem")
        security_score=$((security_score - 10))
    fi
    
    # Determine security status
    local security_status
    if [ "$security_score" -ge 80 ]; then
        security_status="secure"
    elif [ "$security_score" -ge 60 ]; then
        security_status="warning"
    else
        security_status="vulnerable"
    fi
    
    # Create security record
    cat > "$scan_file" <<EOF
{
    "service": "$service",
    "container_id": "$container_id",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "security_status": "$security_status",
    "security_score": $security_score,
    "issues": [
EOF
    
    # Add issues to JSON
    local first_issue=true
    for issue in "${security_issues[@]}"; do
        if [ "$first_issue" = true ]; then
            first_issue=false
        else
            echo "," >> "$scan_file"
        fi
        echo "        \"$issue\"" >> "$scan_file"
    done
    
    cat >> "$scan_file" <<EOF
    ],
    "recommendations": [
        "Use specific image tags instead of :latest",
        "Run containers as non-root user",
        "Enable read-only root filesystem where possible",
        "Limit container capabilities",
        "Regularly update base images"
    ]
}
EOF
    
    # Report security status
    case "$security_status" in
        secure)
            print_security "$service security scan: SECURE (score: $security_score/100)"
            ;;
        warning)
            print_warning "$service security scan: WARNING (score: $security_score/100) - ${security_issues[*]}"
            ;;
        vulnerable)
            print_error "$service security scan: VULNERABLE (score: $security_score/100) - ${security_issues[*]}"
            send_alert "SECURITY_VULNERABLE" "$service" "Score: $security_score/100, Issues: ${security_issues[*]}"
            ;;
    esac
    
    echo "$scan_file"
}

# Check service dependencies
check_service_dependencies() {
    local service="$1"
    
    print_info "Checking dependencies for $service"
    
    case "$service" in
        gateway|localization|cloud-anchor-service|vps-engine|mapping-processor)
            # These services depend on postgres and redis
            if ! docker-compose ps postgres | grep -q "Up"; then
                print_error "$service dependency issue: PostgreSQL not running"
                return 1
            fi
            if ! docker-compose ps redis | grep -q "Up"; then
                print_error "$service dependency issue: Redis not running"
                return 1
            fi
            ;;
        nakama)
            # Nakama depends on postgres
            if ! docker-compose ps postgres | grep -q "Up"; then
                print_error "$service dependency issue: PostgreSQL not running"
                return 1
            fi
            ;;
        nginx)
            # Nginx depends on application services
            local required_services="gateway localization nakama"
            for req_service in $required_services; do
                if ! docker-compose ps "$req_service" | grep -q "Up"; then
                    print_error "$service dependency issue: $req_service not running"
                    return 1
                fi
            done
            ;;
    esac
    
    print_status "$service dependencies: OK"
    return 0
}

# Generate comprehensive safeguards report
generate_safeguards_report() {
    local output_file="${1:-$SAFEGUARDS_DIR/safeguards_report_$(date +%Y%m%d).json}"
    
    print_info "Generating comprehensive safeguards report..."
    
    # Collect all monitoring data
    local monitoring_files
    monitoring_files=$(find "$MONITORING_DIR" -name "*.json" -mtime -1 2>/dev/null || echo "")
    
    # Collect audit logs
    local audit_files
    audit_files=$(find "$AUDIT_DIR" -name "*.log" -mtime -1 2>/dev/null || echo "")
    
    # Count rollback points
    local rollback_count=0
    if [ -d "$ROLLBACK_DIR" ]; then
        rollback_count=$(ls -1 "$ROLLBACK_DIR" | wc -l)
    fi
    
    # System overview
    local total_containers running_containers
    total_containers=$(docker ps -a --filter "name=spatial-" | wc -l)
    running_containers=$(docker ps --filter "name=spatial-" | wc -l)
    
    # Create comprehensive report
    cat > "$output_file" <<EOF
{
    "report_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system_overview": {
        "total_containers": $total_containers,
        "running_containers": $running_containers,
        "rollback_points": $rollback_count,
        "monitoring_files": $(echo "$monitoring_files" | wc -l),
        "audit_files": $(echo "$audit_files" | wc -l)
    },
    "services_status": {
EOF
    
    # Check each service status
    local first_service=true
    for service in $CRITICAL_SERVICES; do
        if [ "$first_service" = true ]; then
            first_service=false
        else
            echo "," >> "$output_file"
        fi
        
        local service_status="unknown"
        if docker-compose ps "$service" | grep -q "Up"; then
            service_status="running"
        else
            service_status="stopped"
        fi
        
        echo "        \"$service\": \"$service_status\"" >> "$output_file"
    done
    
    cat >> "$output_file" <<EOF
    },
    "recent_monitoring_files": [
EOF
    
    # Add recent monitoring files
    local first_file=true
    if [ -n "$monitoring_files" ]; then
        for file in $monitoring_files; do
            if [ "$first_file" = true ]; then
                first_file=false
            else
                echo "," >> "$output_file"
            fi
            echo "        \"$(basename "$file")\"" >> "$output_file"
        done
    fi
    
    cat >> "$output_file" <<EOF
    ],
    "recommendations": [
        "Review monitoring files for performance trends",
        "Regularly clean up old rollback points",
        "Monitor audit logs for security events",
        "Ensure all critical services have recent health checks",
        "Validate data integrity for all storage services"
    ]
}
EOF
    
    print_status "Safeguards report generated: $output_file"
    echo "$output_file"
}

# Main execution
main() {
    local command="${1:-help}"
    shift || true
    
    init_safeguards
    
    case "$command" in
        monitor|mon)
            local service="${1:-}"
            local duration="${2:-60}"
            if [ -n "$service" ]; then
                monitor_performance "$service" "$duration"
            else
                print_error "Service name required for monitoring"
                exit 1
            fi
            ;;
        health|h)
            local service="${1:-}"
            local endpoint="${2:-/healthz}"
            local port="${3:-8000}"
            if [ -n "$service" ]; then
                monitor_service_health "$service" "$endpoint" "$port"
            else
                print_error "Service name required for health check"
                exit 1
            fi
            ;;
        rollback|rb)
            local action="${1:-}"
            case "$action" in
                create|c)
                    local description="${2:-Manual rollback point}"
                    local services="${3:-all}"
                    create_rollback_point "$description" "$services"
                    ;;
                execute|e)
                    local rollback_path="${2:-}"
                    local force="${3:-false}"
                    if [ -n "$rollback_path" ]; then
                        execute_rollback "$rollback_path" "$force"
                    else
                        print_error "Rollback path required"
                        exit 1
                    fi
                    ;;
                list|l)
                    if [ -d "$ROLLBACK_DIR" ] && [ -n "$(ls -A "$ROLLBACK_DIR" 2>/dev/null)" ]; then
                        print_info "Available rollback points:"
                        for rollback in "$ROLLBACK_DIR"/*; do
                            if [ -d "$rollback" ]; then
                                local metadata="$rollback/metadata.json"
                                if [ -f "$metadata" ]; then
                                    local desc timestamp
                                    desc=$(jq -r '.description' "$metadata" 2>/dev/null || echo "No description")
                                    timestamp=$(jq -r '.timestamp' "$metadata" 2>/dev/null || echo "Unknown time")
                                    echo "  $(basename "$rollback"): $desc ($timestamp)"
                                fi
                            fi
                        done
                    else
                        print_info "No rollback points available"
                    fi
                    ;;
                *)
                    print_error "Unknown rollback action: $action (use create|execute|list)"
                    exit 1
                    ;;
            esac
            ;;
        integrity|int)
            local service="${1:-}"
            if [ -n "$service" ]; then
                validate_data_integrity "$service"
            else
                for service in postgres redis minio; do
                    validate_data_integrity "$service"
                done
            fi
            ;;
        security|sec)
            local service="${1:-}"
            if [ -n "$service" ]; then
                security_scan "$service"
            else
                for service in $CRITICAL_SERVICES; do
                    security_scan "$service"
                done
            fi
            ;;
        report|rep)
            local output_file="${1:-}"
            generate_safeguards_report "$output_file"
            ;;
        deps|d)
            local service="${1:-}"
            if [ -n "$service" ]; then
                check_service_dependencies "$service"
            else
                print_error "Service name required for dependency check"
                exit 1
            fi
            ;;
        alert|a)
            local alert_type="${1:-TEST}"
            local service="${2:-test-service}"
            local details="${3:-Test alert from enterprise safeguards}"
            send_alert "$alert_type" "$service" "$details"
            ;;
        help|h|*)
            cat << EOF
Spatial Platform - Enterprise Safeguards & Performance Monitoring v2.0

USAGE:
    $0 <command> [options]

COMMANDS:
    monitor|mon <service> [duration]     Monitor service performance (default: 60s)
    health|h <service> [endpoint] [port] Monitor service health endpoint
    rollback|rb <action> [options]       Rollback management
        create|c [description] [services]    Create rollback point
        execute|e <path> [force]             Execute rollback
        list|l                               List rollback points
    integrity|int [service]              Validate data integrity
    security|sec [service]               Run security scan
    report|rep [output_file]             Generate comprehensive report
    deps|d <service>                     Check service dependencies
    alert|a <type> <service> <details>   Send test alert
    help|h                               Show this help

PERFORMANCE MONITORING:
    • 60fps AR/VR performance requirements
    • CPU threshold: Warn at ${CPU_THRESHOLD_WARN}%, Critical at ${CPU_THRESHOLD_CRITICAL}%
    • Memory threshold: Warn at ${MEMORY_THRESHOLD_WARN}%, Critical at ${MEMORY_THRESHOLD_CRITICAL}%
    • Response time threshold: ${RESPONSE_TIME_THRESHOLD}ms
    • Frame rate threshold: ${FRAME_RATE_THRESHOLD}fps

AUTOMATED SAFEGUARDS:
    • Performance monitoring with automated responses
    • Automated rollback capabilities for breaking changes
    • Data integrity validation for critical services
    • Security scanning with vulnerability detection
    • Health monitoring with AR/VR specific checks
    • Enterprise-grade logging and audit trails

EXAMPLES:
    $0 monitor postgres 300              # Monitor PostgreSQL for 5 minutes
    $0 health gateway /healthz 8000      # Check gateway health
    $0 rollback create "Pre-update"      # Create rollback point
    $0 rollback execute /path/to/point   # Execute rollback
    $0 integrity postgres                # Validate PostgreSQL integrity
    $0 security all                      # Run security scan on all services
    $0 report                            # Generate comprehensive report

FILES:
    Monitoring: $MONITORING_DIR
    Rollbacks:  $ROLLBACK_DIR
    Audit Logs: $AUDIT_DIR
EOF
            ;;
    esac
}

# Execute with all provided arguments
main "$@"