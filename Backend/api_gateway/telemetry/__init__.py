"""
Spatial API Gateway - Enterprise Telemetry Package
Modular telemetry system with enterprise-grade monitoring
"""

from .route_monitor import RoutePerformanceMonitor
from .security_monitor import SecurityMonitor

# Initialize gateway telemetry (placeholder implementations)
_gateway_telemetry = None

def initialize_gateway_telemetry():
    """Initialize gateway-specific telemetry"""
    global _gateway_telemetry
    _gateway_telemetry = {
        'route_monitor': RoutePerformanceMonitor(),
        'security_monitor': SecurityMonitor()
    }
    return _gateway_telemetry

def get_gateway_telemetry():
    """Get gateway telemetry instance"""
    return _gateway_telemetry

# Middleware placeholder
class EnterpriseTelemetryMiddleware:
    """Enterprise telemetry middleware for FastAPI"""
    def __init__(self, app, **kwargs):
        self.app = app
        # Accept any additional arguments
        for key, value in kwargs.items():
            setattr(self, key, value)
    
    async def __call__(self, scope, receive, send):
        return await self.app(scope, receive, send)

# Decorator placeholders
def trace_api_route(*args, **kwargs):
    """Decorator to trace API routes"""
    def decorator(func):
        return func
    
    # If called with function directly, return the function
    if len(args) == 1 and callable(args[0]):
        return args[0]
    # If called with parameters, return the decorator
    return decorator

def trace_backend_call(*args, **kwargs):
    """Decorator to trace backend calls"""
    def decorator(func):
        return func
    
    # If called with function directly, return the function
    if len(args) == 1 and callable(args[0]):
        return args[0]
    # If called with parameters, return the decorator
    return decorator

__all__ = [
    'RoutePerformanceMonitor',
    'SecurityMonitor',
    'initialize_gateway_telemetry',
    'get_gateway_telemetry',
    'EnterpriseTelemetryMiddleware',
    'trace_api_route',
    'trace_backend_call'
]