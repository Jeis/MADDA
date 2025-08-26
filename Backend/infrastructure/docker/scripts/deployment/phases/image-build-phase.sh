#!/usr/bin/env bash

# Spatial Platform - Image Build Phase  
# Extracted from deploy.sh as part of PROJECT_STANDARDS.md compliance
# Version: 1.0.0

# Phase 3: Enterprise image building and management
phase_image_build() {
    print_info "=== Phase 3: Enterprise Image Management ==="
    CURRENT_PHASE="IMAGE_BUILD"
    save_checkpoint "$CURRENT_PHASE" "started"
    
    # Set Docker BuildKit for optimization
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    print_info "Docker BuildKit enabled for optimized builds"
    
    local step=0
    local total=4
    
    track_progress $((++step)) $total "Pulling external images"
    
    print_info "Pulling external service images..."
    local external_pulls=0
    for service in $EXTERNAL_SERVICES; do
        if docker-compose pull "$service" >/dev/null 2>&1; then
            external_pulls=$((external_pulls + 1))
        fi
    done
    print_status "Pulled $external_pulls external images"
    
    track_progress $((++step)) $total "Building custom services"
    
    print_info "Analyzing build requirements..."
    local services_to_build=""
    local heavy_services_to_build=""
    local light_services_to_build=""
    local total_builds=0
    
    for service in $BUILD_SERVICES; do
        if ! is_service_built "$service"; then
            services_to_build="$services_to_build $service"
            total_builds=$((total_builds + 1))
            
            # Categorize as heavy or light
            local is_heavy=false
            for heavy in $HEAVY_SERVICES; do
                if [ "$service" = "$heavy" ]; then
                    is_heavy=true
                    break
                fi
            done
            
            if [ "$is_heavy" = "true" ]; then
                heavy_services_to_build="$heavy_services_to_build $service"
            else
                light_services_to_build="$light_services_to_build $service"
            fi
        fi
    done
    
    if [ $total_builds -eq 0 ]; then
        print_status "All custom images already built"
    else
        print_info "Building $total_builds custom services:$services_to_build"
        
        track_progress $((++step)) $total "Building heavy services"
        
        # Optimized build strategy: Light services in parallel, heavy services with resource management
        local build_failed=false
        
        # Build light services in parallel first (they're faster and use less resources)
        if [ -n "$light_services_to_build" ]; then
            local light_count=$(echo $light_services_to_build | wc -w)
            print_build_optimization "Building $light_count light services in parallel..."
            local build_pids=()
            local active_builds=()
            
            for service in $light_services_to_build; do
                if [[ ${#active_builds[@]} -lt $MAX_PARALLEL_BUILDS ]]; then
                    print_info "Starting parallel build: $service"
                    build_service_enhanced "$service" "false" &
                    local pid=$!
                    active_builds+=("$service")
                    build_pids+=("$pid")
                else
                    # Wait for one to complete
                    wait ${build_pids[0]}
                    if [[ $? -ne 0 ]]; then
                        print_error "${active_builds[0]} build failed"
                        build_failed=true
                    fi
                    
                    # Remove completed build and start new one
                    active_builds=("${active_builds[@]:1}")
                    build_pids=("${build_pids[@]:1}")
                    
                    print_info "Starting parallel build: $service"
                    build_service_enhanced "$service" "false" &
                    local pid=$!
                    active_builds+=("$service")
                    build_pids+=("$pid")
                fi
            done
            
            # Wait for remaining builds to complete
            for i in "${!build_pids[@]}"; do
                wait "${build_pids[i]}"
                if [[ $? -ne 0 ]]; then
                    print_error "${active_builds[i]} build failed"
                    build_failed=true
                fi
            done
        fi
        
        track_progress $((++step)) $total "Building heavy services with optimization"
        
        # Build heavy services sequentially with enhanced resource management
        if [ -n "$heavy_services_to_build" ]; then
            print_build_optimization "Building heavy services with resource optimization..."
            print_info "Building heavy services sequentially:$heavy_services_to_build"
            for service in $heavy_services_to_build; do
                print_build_optimization "Building heavy service: $service (memory management enabled)"
                if ! build_service_enhanced "$service" "true"; then
                    build_failed=true
                fi
            done
        fi
        
        # Check if any builds failed
        if [ "$build_failed" = true ]; then
            print_error "Some service builds failed - check logs in $STATE_DIR/"
            return 1
        fi
    fi
    
    # Validation
    print_info "Validating built images..."
    local built_count=0
    local total_expected
    total_expected=$(echo "$BUILD_SERVICES" | wc -w | tr -d ' ')
    
    for service in $BUILD_SERVICES; do
        if is_service_built "$service"; then
            built_count=$((built_count + 1))
        fi
    done
    
    print_info "Build summary: $built_count/$total_expected images available"
    
    if [ $built_count -ge $((total_expected * 7 / 10)) ]; then
        print_status "Sufficient images built (≥70%) - deployment can proceed"
    else
        print_warning "Limited images available (<70%) - some services may not start"
    fi
    
    save_checkpoint "$CURRENT_PHASE" "completed"
}