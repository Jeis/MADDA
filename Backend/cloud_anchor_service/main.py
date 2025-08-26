#!/usr/bin/env python3

import os
import asyncio
import logging
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
import uvicorn
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Dict, List, Optional, Any

from core.anchor_manager import AnchorManager
from core.persistence_engine import PersistenceEngine
from core.synchronization_manager import SynchronizationManager
from api.routes import router as api_router, set_services
from utils.config import settings
from utils.metrics import setup_metrics

logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s [%(name)s:%(lineno)d] [cloud-anchor-service] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

anchor_manager = None
persistence_engine = None
sync_manager = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manages anchor service lifecycle - handles persistence layer and sync channels"""
    global anchor_manager, persistence_engine, sync_manager
    
    logger.info("Initializing cloud anchor persistence layer")
    try:
        persistence_engine = PersistenceEngine()
        await persistence_engine.initialize()
        
        anchor_manager = AnchorManager(persistence_engine)
        await anchor_manager.initialize()
        
        sync_manager = SynchronizationManager(anchor_manager)
        await sync_manager.initialize()
        
        setup_metrics()
        
        set_services(anchor_manager, persistence_engine, sync_manager)
        
        logger.info(f"Anchor service ready - {anchor_manager.anchor_count} anchors loaded")
        yield
        
    except Exception as e:
        logger.error(f"Anchor service startup failed - persistence layer error: {e}")
        raise
    finally:
        logger.info("Flushing anchor cache and closing sync channels")
        if sync_manager:
            await sync_manager.shutdown()
        if anchor_manager:
            await anchor_manager.shutdown()
        if persistence_engine:
            await persistence_engine.shutdown()

app = FastAPI(
    title="Spatial Cloud Anchor Service",
    description="Persistent spatial anchors for cross-platform AR experiences",
    version="1.0.0",
    docs_url="/docs" if settings.ENVIRONMENT == "development" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT == "development" else None,
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")

@app.get("/health")
async def health_check():
    """Verifies anchor service health - checks database connectivity and sync status - full logging enabled"""
    try:
        services_healthy = True
        services_status = {}
        
        if anchor_manager:
            services_status['anchor_manager'] = await anchor_manager.health_check()
        else:
            services_status['anchor_manager'] = False
        
        if persistence_engine:
            services_status['persistence_engine'] = await persistence_engine.health_check()
        else:
            services_status['persistence_engine'] = False
        
        if sync_manager:
            services_status['sync_manager'] = await sync_manager.health_check()
        else:
            services_status['sync_manager'] = False
        
        services_healthy = all(services_status.values())
        
        if services_healthy:
            return {
                "status": "healthy",
                "service": "cloud-anchor-service",
                "version": "1.0.0",
                "endpoint": "health",
                "logging": "enabled",
                "timestamp": datetime.utcnow().isoformat(),
                "services": services_status
            }
        else:
            return JSONResponse(
                status_code=503,
                content={
                    "status": "unhealthy",
                    "service": "cloud-anchor-service",
                    "endpoint": "health",
                    "logging": "enabled",
                    "services": services_status,
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy", 
                "service": "cloud-anchor-service",
                "endpoint": "health",
                "logging": "enabled",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/healthz")
async def health_check_minimal():
    """Minimal health check for Docker/K8s - no logging"""
    try:
        # Quick checks only - no detailed status
        basic_health = anchor_manager is not None and persistence_engine is not None
        
        if basic_health:
            return {
                "status": "healthy",
                "service": "cloud-anchor-service",
                "endpoint": "healthz"
            }
        else:
            return JSONResponse(
                status_code=503,
                content={
                    "status": "unhealthy",
                    "service": "cloud-anchor-service",
                    "endpoint": "healthz"
                }
            )
    except Exception:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "cloud-anchor-service",
                "endpoint": "healthz"
            }
        )

# Metrics endpoint
@app.get("/metrics", response_class=PlainTextResponse)
async def prometheus_metrics():
    """
    Enterprise Prometheus metrics endpoint - PROJECT_STANDARDS.md compliant
    Cloud anchor persistence and synchronization metrics
    """
    import time
    
    try:
        current_time = time.time()
        metrics_output = []
        
        # Service information
        metrics_output.append("# HELP spatial_cloud_anchors_info Cloud anchor service information")
        metrics_output.append("# TYPE spatial_cloud_anchors_info gauge")
        metrics_output.append(f'spatial_cloud_anchors_info{{version="1.0.0",environment="{os.getenv("ENVIRONMENT", "development")}"}} 1')
        
        # Service health metrics
        service_up = 1 if (anchor_manager and persistence_engine and sync_manager) else 0
        metrics_output.append("# HELP spatial_cloud_anchors_up Service availability")
        metrics_output.append("# TYPE spatial_cloud_anchors_up gauge")
        metrics_output.append(f"spatial_cloud_anchors_up {service_up}")
        
        # Anchor metrics (if available)
        if anchor_manager:
            try:
                anchor_metrics = await anchor_manager.get_metrics()
                
                # Total anchors
                total_anchors = anchor_metrics.get("total_anchors", 0)
                metrics_output.append("# HELP spatial_cloud_anchors_total Total number of anchors")
                metrics_output.append("# TYPE spatial_cloud_anchors_total gauge")
                metrics_output.append(f"spatial_cloud_anchors_total {total_anchors}")
                
                # Active sessions
                active_sessions = anchor_metrics.get("active_sessions", 0)
                metrics_output.append("# HELP spatial_cloud_anchors_sessions Active anchor sessions")
                metrics_output.append("# TYPE spatial_cloud_anchors_sessions gauge")
                metrics_output.append(f"spatial_cloud_anchors_sessions {active_sessions}")
                
            except Exception as e:
                logger.warning(f"Failed to get anchor metrics: {e}")
        
        # Persistence metrics (if available)
        if persistence_engine:
            try:
                persistence_metrics = await persistence_engine.get_metrics()
                
                # Storage usage
                storage_bytes = persistence_metrics.get("storage_bytes", 0)
                metrics_output.append("# HELP spatial_cloud_anchors_storage_bytes Storage used in bytes")
                metrics_output.append("# TYPE spatial_cloud_anchors_storage_bytes gauge")
                metrics_output.append(f"spatial_cloud_anchors_storage_bytes {storage_bytes}")
                
            except Exception as e:
                logger.warning(f"Failed to get persistence metrics: {e}")
        
        # Synchronization metrics (if available)
        if sync_manager:
            try:
                sync_metrics = await sync_manager.get_metrics()
                
                # Sync operations
                sync_ops = sync_metrics.get("sync_operations_total", 0)
                metrics_output.append("# HELP spatial_cloud_anchors_sync_operations_total Total sync operations")
                metrics_output.append("# TYPE spatial_cloud_anchors_sync_operations_total counter")
                metrics_output.append(f"spatial_cloud_anchors_sync_operations_total {sync_ops}")
                
            except Exception as e:
                logger.warning(f"Failed to get sync metrics: {e}")
        
        # System timestamp
        metrics_output.append("# HELP spatial_cloud_anchors_last_update_timestamp Last metrics update")
        metrics_output.append("# TYPE spatial_cloud_anchors_last_update_timestamp gauge")
        metrics_output.append(f"spatial_cloud_anchors_last_update_timestamp {current_time}")
        
        return "\n".join(metrics_output)
        
    except Exception as e:
        logger.error(f"Metrics generation failed: {e}")
        # Return minimal error metrics
        error_metrics = [
            "# HELP spatial_cloud_anchors_metrics_errors_total Metrics generation errors",
            "# TYPE spatial_cloud_anchors_metrics_errors_total counter",
            "spatial_cloud_anchors_metrics_errors_total 1",
            f"# Error: {str(e)}"
        ]
        return "\n".join(error_metrics)

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with service information"""
    return {
        "service": "Spatial Cloud Anchor Service",
        "description": "Persistent spatial anchors for AR applications",
        "version": "1.0.0",
        "status": "operational",
        "features": [
            "Cross-platform anchor persistence",
            "Real-time synchronization",
            "Spatial indexing and queries",
            "Anchor sharing and collaboration",
            "Quality tracking and optimization"
        ],
        "docs": "/docs" if settings.ENVIRONMENT == "development" else "disabled",
        "health": "/health",
        "metrics": "/metrics"
    }

# Dependency injection for services
def get_anchor_manager():
    """Get anchor manager instance"""
    if not anchor_manager:
        raise HTTPException(status_code=503, detail="Anchor manager not initialized")
    return anchor_manager

def get_persistence_engine():
    """Get persistence engine instance"""
    if not persistence_engine:
        raise HTTPException(status_code=503, detail="Persistence engine not initialized")
    return persistence_engine

def get_sync_manager():
    """Get synchronization manager instance"""
    if not sync_manager:
        raise HTTPException(status_code=503, detail="Synchronization manager not initialized")
    return sync_manager

if __name__ == "__main__":
    # Development server
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=settings.PORT,
        reload=settings.ENVIRONMENT == "development",
        log_level=settings.LOG_LEVEL.lower(),
        access_log=True
    )