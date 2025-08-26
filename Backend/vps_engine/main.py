#!/usr/bin/env python3

import os
import asyncio
import logging
from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
import uvicorn
from contextlib import asynccontextmanager

from core.vps_engine import VPSEngine
from core.pose_estimator import PoseEstimator
from core.map_matcher import MapMatcher
from api.routes import router as api_router
from utils.config import settings
from utils.metrics import setup_metrics

logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s [%(name)s:%(lineno)d] [vps-engine] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

vps_engine = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manages VPS engine lifecycle - handles GPU allocation and feature matcher initialization"""
    global vps_engine
    
    logger.info("Starting VPS Engine with GPU node allocation")
    try:
        vps_engine = VPSEngine()
        await vps_engine.initialize()
        
        setup_metrics()
        
        logger.info(f"VPS Engine ready - allocated {vps_engine.gpu_count} GPU nodes")
        yield
        
    except Exception as e:
        logger.error(f"VPS initialization failed - GPU allocation issue: {e}")
        raise
    finally:
        logger.info("Releasing GPU resources and closing feature matchers")
        if vps_engine:
            await vps_engine.shutdown()

app = FastAPI(
    title="Spatial VPS Engine",
    description="Visual Positioning System for centimeter-level AR localization",
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
    """Validates VPS engine readiness - checks GPU availability and feature matcher status"""
    try:
        if vps_engine and await vps_engine.health_check():
            return {
                "status": "healthy",
                "service": "vps-engine",
                "version": "1.0.0",
                "endpoint": "health",
                "logging": "enabled",
                "timestamp": settings.get_timestamp(),
                "engine_status": "operational"
            }
        else:
            return JSONResponse(
                status_code=503,
                content={
                    "status": "unhealthy",
                    "service": "vps-engine",
                    "endpoint": "health",
                    "logging": "enabled",
                    "error": "VPS engine not ready"
                }
            )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy", 
                "service": "vps-engine",
                "endpoint": "health",
                "logging": "enabled",
                "error": str(e)
            }
        )


@app.get("/healthz")
async def health_check_minimal():
    """Minimal health check for Docker/K8s - no logging"""
    try:
        # Quick engine availability check only
        if vps_engine:
            return {
                "status": "healthy",
                "service": "vps-engine",
                "endpoint": "healthz"
            }
        else:
            return JSONResponse(
                status_code=503,
                content={
                    "status": "unhealthy",
                    "service": "vps-engine",
                    "endpoint": "healthz"
                }
            )
    except Exception:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "vps-engine",
                "endpoint": "healthz"
            }
        )


@app.get("/metrics", response_class=PlainTextResponse)
async def prometheus_metrics():
    from fastapi.responses import PlainTextResponse
    import time
    
    try:
        current_time = time.time()
        metrics_output = []
        
        metrics_output.append("# HELP spatial_vps_engine_info VPS engine service information")
        metrics_output.append("# TYPE spatial_vps_engine_info gauge")
        metrics_output.append(f'spatial_vps_engine_info{{version="1.0.0",environment="{settings.ENVIRONMENT}"}} 1')
        
        service_up = 1 if vps_engine else 0
        metrics_output.append("# HELP spatial_vps_engine_up Service availability")
        metrics_output.append("# TYPE spatial_vps_engine_up gauge")
        metrics_output.append(f"spatial_vps_engine_up {service_up}")
        
        if vps_engine:
            try:
                vps_metrics = await vps_engine.get_metrics()
                
                localization_requests = vps_metrics.get("localization_requests_total", 0)
                metrics_output.append("# HELP spatial_vps_localization_requests_total Total localization requests")
                metrics_output.append("# TYPE spatial_vps_localization_requests_total counter")
                metrics_output.append(f"spatial_vps_localization_requests_total {localization_requests}")
                
                active_maps = vps_metrics.get("active_maps", 0)
                metrics_output.append("# HELP spatial_vps_active_maps Active VPS maps")
                metrics_output.append("# TYPE spatial_vps_active_maps gauge")
                metrics_output.append(f"spatial_vps_active_maps {active_maps}")
                
                avg_processing_time = vps_metrics.get("avg_processing_time_ms", 0)
                metrics_output.append("# HELP spatial_vps_processing_time_ms Average processing time")
                metrics_output.append("# TYPE spatial_vps_processing_time_ms gauge")
                metrics_output.append(f"spatial_vps_processing_time_ms {avg_processing_time}")
                
                success_rate = vps_metrics.get("success_rate", 0)
                metrics_output.append("# HELP spatial_vps_success_rate Localization success rate")
                metrics_output.append("# TYPE spatial_vps_success_rate gauge")
                metrics_output.append(f"spatial_vps_success_rate {success_rate}")
                
            except Exception as e:
                logger.warning(f"Metrics collection failed for VPS engine: {e}")
        
        metrics_output.append("# HELP spatial_vps_engine_last_update_timestamp Last metrics update")
        metrics_output.append("# TYPE spatial_vps_engine_last_update_timestamp gauge")
        metrics_output.append(f"spatial_vps_engine_last_update_timestamp {current_time}")
        
        return "\n".join(metrics_output)
        
    except Exception as e:
        logger.error(f"Metrics endpoint failure - likely memory issue: {e}")
        error_metrics = [
            "# HELP spatial_vps_engine_metrics_errors_total Metrics generation errors",
            "# TYPE spatial_vps_engine_metrics_errors_total counter",
            "spatial_vps_engine_metrics_errors_total 1"
        ]
        return "\n".join(error_metrics)

@app.get("/")
async def root():
    """Service discovery endpoint for health monitoring and feature detection"""
    return {
        "service": "Spatial VPS Engine",
        "description": "Visual Positioning System for AR applications",
        "version": "1.0.0",
        "status": "operational" if vps_engine else "initializing",
        "docs": "/docs" if settings.ENVIRONMENT == "development" else "disabled",
        "health": "/health",
        "metrics": "/metrics"
    }

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