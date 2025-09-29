from pydantic_settings import BaseSettings
from typing import List, Optional, Dict, Any
import os

class EnterpriseSettings(BaseSettings):
    # Application
    PROJECT_NAME: str = "Enterprise Multi-tenant AI Platform"
    VERSION: str = "2.0.0"
    DEBUG: bool = False
    SECRET_KEY: str = "your-enterprise-secret-key-change-in-production"
    
    # Multi-tenant Configuration
    MAX_TENANTS: int = 1000
    MAX_USERS_PER_TENANT: int = 1000
    MAX_CONCURRENT_USERS: int = 10000
    
    # Database Configuration
    DATABASE_URL: str = "postgresql://postgres:password@localhost:5432/multitenant_ai"
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 30
    DATABASE_POOL_TIMEOUT: int = 30
    DATABASE_POOL_RECYCLE: int = 3600
    
    # Redis Configuration
    REDIS_URL: str = "redis://localhost:6379"
    REDIS_POOL_SIZE: int = 50
    REDIS_MAX_CONNECTIONS: int = 100
    
    # AWS Configuration
    AWS_REGION: str = "us-east-1"
    AWS_ACCESS_KEY_ID: Optional[str] = None
    AWS_SECRET_ACCESS_KEY: Optional[str] = None
    
    # Bedrock Configuration
    BEDROCK_REGION: str = "us-east-1"
    BEDROCK_MAX_CONCURRENT_REQUESTS: int = 100
    BEDROCK_REQUEST_TIMEOUT: int = 300
    
    # CORS Configuration
    ALLOWED_HOSTS: List[str] = ["*"]
    CORS_ORIGINS: List[str] = ["*"]
    
    # JWT Configuration
    JWT_SECRET_KEY: str = "your-jwt-secret-key"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # Rate Limiting Configuration
    RATE_LIMIT_PER_MINUTE: int = 1000
    RATE_LIMIT_PER_HOUR: int = 10000
    RATE_LIMIT_PER_DAY: int = 100000
    
    # Tenant-specific Rate Limiting
    TENANT_RATE_LIMIT_PER_MINUTE: int = 100
    TENANT_RATE_LIMIT_PER_HOUR: int = 1000
    TENANT_RATE_LIMIT_PER_DAY: int = 10000
    
    # Vector Database Configuration
    CHROMA_PERSIST_DIRECTORY: str = "/tmp/chroma_db"
    CHROMA_COLLECTION_LIMIT: int = 10000
    
    # Logging Configuration
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"
    LOG_FILE: str = "/var/log/ai-platform/app.log"
    LOG_MAX_SIZE: int = 100  # MB
    LOG_BACKUP_COUNT: int = 5
    
    # Monitoring Configuration
    ENABLE_METRICS: bool = True
    METRICS_PORT: int = 9090
    HEALTH_CHECK_INTERVAL: int = 30
    
    # Caching Configuration
    CACHE_TTL: int = 3600  # 1 hour
    CACHE_MAX_SIZE: int = 1000
    
    # File Upload Configuration
    MAX_FILE_SIZE: int = 100 * 1024 * 1024  # 100MB
    ALLOWED_FILE_TYPES: List[str] = ["txt", "pdf", "docx", "md"]
    
    # Email Configuration
    SMTP_HOST: Optional[str] = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_USE_TLS: bool = True
    
    # Notification Configuration
    ENABLE_NOTIFICATIONS: bool = True
    NOTIFICATION_CHANNELS: List[str] = ["email", "webhook"]
    
    # Backup Configuration
    BACKUP_ENABLED: bool = True
    BACKUP_INTERVAL: int = 24  # hours
    BACKUP_RETENTION_DAYS: int = 30
    
    # Security Configuration
    ENABLE_2FA: bool = True
    SESSION_TIMEOUT: int = 3600  # 1 hour
    MAX_LOGIN_ATTEMPTS: int = 5
    LOCKOUT_DURATION: int = 900  # 15 minutes
    
    # Performance Configuration
    WORKER_PROCESSES: int = 4
    WORKER_THREADS: int = 2
    MAX_REQUESTS: int = 1000
    MAX_REQUESTS_JITTER: int = 100
    
    # GPU Configuration
    ENABLE_GPU: bool = True
    GPU_MEMORY_LIMIT: int = 8192  # MB
    GPU_UTILIZATION_THRESHOLD: float = 0.8
    
    # Load Balancing Configuration
    ENABLE_LOAD_BALANCING: bool = True
    LOAD_BALANCE_STRATEGY: str = "round_robin"
    
    # Auto-scaling Configuration
    ENABLE_AUTO_SCALING: bool = True
    MIN_INSTANCES: int = 3
    MAX_INSTANCES: int = 50
    SCALE_UP_THRESHOLD: float = 0.7
    SCALE_DOWN_THRESHOLD: float = 0.3
    
    # Cost Management Configuration
    ENABLE_COST_TRACKING: bool = True
    COST_ALERT_THRESHOLD: float = 1000.0  # USD
    BUDGET_LIMIT: float = 10000.0  # USD
    
    # Compliance Configuration
    ENABLE_AUDIT_LOGGING: bool = True
    AUDIT_LOG_RETENTION_DAYS: int = 2555  # 7 years
    ENABLE_DATA_ENCRYPTION: bool = True
    
    # Multi-region Configuration
    ENABLE_MULTI_REGION: bool = False
    PRIMARY_REGION: str = "us-east-1"
    SECONDARY_REGIONS: List[str] = ["us-west-2", "eu-west-1"]
    
    # CDN Configuration
    ENABLE_CDN: bool = True
    CDN_CACHE_TTL: int = 86400  # 24 hours
    
    # API Versioning
    API_VERSION: str = "v1"
    ENABLE_API_VERSIONING: bool = True
    
    # Feature Flags
    ENABLE_RAG: bool = True
    ENABLE_FINE_TUNING: bool = True
    ENABLE_BATCH_PROCESSING: bool = True
    ENABLE_REAL_TIME_ANALYTICS: bool = True
    
    class Config:
        env_file = ".env"
        case_sensitive = True

enterprise_settings = EnterpriseSettings()
