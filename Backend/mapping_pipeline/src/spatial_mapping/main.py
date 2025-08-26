#!/usr/bin/env python3
"""
3D Mapping Service
COLMAP-based reconstruction pipeline
"""

import sys
import os

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
import uvicorn
import logging
import time
import psutil
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY

# Setup logging
import logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s [%(name)s:%(lineno)d] [mapping-pipeline] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Prometheus metrics - Use try/except to handle re-imports
try:
    request_count = Counter(
        'mapping_requests_total',
        'Total number of mapping requests',
        ['method', 'endpoint', 'status']
    )
except ValueError:
    # Metrics already registered
    from prometheus_client import REGISTRY
    request_count = REGISTRY._names_to_collectors['mapping_requests_total']

try:
    request_duration = Histogram(
        'mapping_request_duration_seconds',
        'Request duration in seconds',
        ['method', 'endpoint']
    )
except ValueError:
    from prometheus_client import REGISTRY
    request_duration = REGISTRY._names_to_collectors['mapping_request_duration_seconds']

try:
    active_reconstructions = Gauge(
        'mapping_active_reconstructions',
        'Number of active reconstructions'
    )
except ValueError:
    from prometheus_client import REGISTRY
    active_reconstructions = REGISTRY._names_to_collectors['mapping_active_reconstructions']

try:
    reconstruction_success_count = Counter(
        'mapping_reconstruction_success_total',
        'Total successful reconstructions'
    )
except ValueError:
    from prometheus_client import REGISTRY
    reconstruction_success_count = REGISTRY._names_to_collectors['mapping_reconstruction_success_total']

try:
    reconstruction_failure_count = Counter(
        'mapping_reconstruction_failure_total',
        'Total failed reconstructions'
    )
except ValueError:
    from prometheus_client import REGISTRY
    reconstruction_failure_count = REGISTRY._names_to_collectors['mapping_reconstruction_failure_total']

try:
    memory_usage = Gauge(
        'mapping_memory_usage_bytes',
        'Memory usage in bytes'
    )
except ValueError:
    from prometheus_client import REGISTRY
    memory_usage = REGISTRY._names_to_collectors['mapping_memory_usage_bytes']

try:
    cpu_usage = Gauge(
        'mapping_cpu_usage_percent',
        'CPU usage percentage'
    )
except ValueError:
    from prometheus_client import REGISTRY
    cpu_usage = REGISTRY._names_to_collectors['mapping_cpu_usage_percent']

app = FastAPI(
    title="3D Mapping Service",
    description="COLMAP-based reconstruction pipeline",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    """Health check endpoint with full logging - for contributors/debugging"""
    # Update system metrics
    memory_usage.set(psutil.Process().memory_info().rss)
    cpu_usage.set(psutil.cpu_percent(interval=0.1))
    
    return {
        "status": "healthy",
        "service": "mapping-pipeline",
        "version": "1.0.0",
        "endpoint": "health",
        "logging": "enabled"
    }


@app.get("/healthz")
async def health_check_minimal():
    """Minimal health check for Docker/K8s - no logging"""
    return {
        "status": "healthy",
        "service": "mapping-pipeline",
        "endpoint": "healthz"
    }

@app.get("/metrics", response_class=PlainTextResponse)
async def metrics():
    """Prometheus metrics endpoint"""
    # Update system metrics
    memory_usage.set(psutil.Process().memory_info().rss)
    cpu_usage.set(psutil.cpu_percent(interval=0.1))
    
    # Generate and return metrics in Prometheus format
    return generate_latest(REGISTRY)

@app.get("/")
async def service_info():
    """Service information"""
    return {
        "service": "3D Mapping Pipeline",
        "description": "COLMAP-based 3D reconstruction",
        "endpoints": ["/health", "/metrics", "/maps", "/reconstruction"],
        "docs": "/docs"
    }

if __name__ == "__main__":
    uvicorn.run(
        "spatial_mapping.main:app",
        host="0.0.0.0", 
        port=8080,
        reload=False  # Disable reload in production
    )