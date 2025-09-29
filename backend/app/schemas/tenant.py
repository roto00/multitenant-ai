from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime

class TenantCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    domain: str = Field(..., min_length=1, max_length=255)
    display_name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    config: Optional[Dict[str, Any]] = None
    is_active: bool = True
    default_model: str = "anthropic.claude-3-sonnet-20240229-v1:0"
    max_tokens: int = Field(4000, ge=1, le=8000)
    temperature: int = Field(70, ge=0, le=100)  # Stored as integer (0-100)
    rate_limit_per_minute: int = Field(60, ge=1, le=1000)
    rate_limit_per_hour: int = Field(1000, ge=1, le=10000)

class TenantUpdate(BaseModel):
    display_name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    config: Optional[Dict[str, Any]] = None
    is_active: Optional[bool] = None
    default_model: Optional[str] = None
    max_tokens: Optional[int] = Field(None, ge=1, le=8000)
    temperature: Optional[int] = Field(None, ge=0, le=100)
    rate_limit_per_minute: Optional[int] = Field(None, ge=1, le=1000)
    rate_limit_per_hour: Optional[int] = Field(None, ge=1, le=10000)

class TenantResponse(BaseModel):
    id: int
    name: str
    domain: str
    display_name: str
    description: Optional[str]
    is_active: bool
    default_model: str
    max_tokens: int
    temperature: int
    rate_limit_per_minute: int
    rate_limit_per_hour: int
    created_at: datetime
    updated_at: Optional[datetime]
