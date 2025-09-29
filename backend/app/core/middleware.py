from fastapi import Request, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response
import structlog
import time
import uuid
from typing import Callable

logger = structlog.get_logger()

class TenantMiddleware(BaseHTTPMiddleware):
    """Middleware to extract tenant information from request"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Extract tenant from subdomain or header
        tenant_id = None
        
        # Try to get tenant from subdomain
        host = request.headers.get("host", "")
        if "." in host:
            subdomain = host.split(".")[0]
            if subdomain != "www" and subdomain != "api":
                tenant_id = subdomain
        
        # Try to get tenant from header
        if not tenant_id:
            tenant_id = request.headers.get("x-tenant-id")
        
        # Add tenant to request state
        request.state.tenant_id = tenant_id
        
        response = await call_next(request)
        return response

class LoggingMiddleware(BaseHTTPMiddleware):
    """Middleware for request/response logging"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Generate request ID
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        
        # Start time
        start_time = time.time()
        
        # Log request
        logger.info(
            "Request started",
            request_id=request_id,
            method=request.method,
            url=str(request.url),
            client_ip=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent"),
            tenant_id=getattr(request.state, "tenant_id", None)
        )
        
        try:
            response = await call_next(request)
            
            # Calculate processing time
            process_time = time.time() - start_time
            
            # Log response
            logger.info(
                "Request completed",
                request_id=request_id,
                status_code=response.status_code,
                process_time=process_time
            )
            
            # Add request ID to response headers
            response.headers["X-Request-ID"] = request_id
            
            return response
            
        except Exception as e:
            process_time = time.time() - start_time
            
            logger.error(
                "Request failed",
                request_id=request_id,
                error=str(e),
                process_time=process_time
            )
            
            raise
