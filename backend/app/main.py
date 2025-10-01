from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import structlog
import uvicorn
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.database import init_db
from app.api.v1.api import api_router
from app.core.middleware import TenantMiddleware, LoggingMiddleware
from app.core.exceptions import setup_exception_handlers

logger = structlog.get_logger()

security = HTTPBearer()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting up multitenant AI application")
    await init_db()
    yield
    # Shutdown
    logger.info("Shutting down multitenant AI application")

app = FastAPI(
    title="Multi-tenant AI Platform",
    description="A scalable multi-tenant AI platform with RAG capabilities",
    version="1.0.0",
    lifespan=lifespan
)

# Simple health check endpoint before middleware
@app.get("/healthz")
async def health_check_simple():
    """Simple health check endpoint for load balancer"""
    return {"status": "ok"}

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_HOSTS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.ALLOWED_HOSTS
)

app.add_middleware(TenantMiddleware)
app.add_middleware(LoggingMiddleware)

# Exception handlers
setup_exception_handlers(app)

# Include API router
app.include_router(api_router, prefix="/api/v1")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "multitenant-ai"}

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Multi-tenant AI Platform",
        "version": "1.0.0",
        "docs": "/docs"
    }

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_config=None  # Use structlog
    )
