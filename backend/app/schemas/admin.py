from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime

class PromptLogResponse(BaseModel):
    id: int
    tenant_id: int
    user_id: Optional[int]
    prompt_text: str
    response_text: Optional[str]
    model_used: str
    input_tokens: Optional[int]
    output_tokens: Optional[int]
    total_tokens: Optional[int]
    latency_ms: Optional[float]
    cost_usd: Optional[float]
    request_id: Optional[str]
    status_code: Optional[int]
    error_message: Optional[str]
    created_at: datetime

class TenantStatsResponse(BaseModel):
    tenant_id: int
    tenant_name: str
    display_name: str
    is_active: bool
    user_count: int
    conversation_count: int
    prompt_count: int
    total_cost: float
    rag_document_count: int
    created_at: datetime

class ModelUsage(BaseModel):
    model: str
    count: int
    cost: float

class UsageStatsResponse(BaseModel):
    period_days: int
    total_prompts: int
    successful_prompts: int
    success_rate: float
    total_tokens: int
    total_cost: float
    average_latency_ms: float
    model_usage: List[ModelUsage]

class SystemStatsResponse(BaseModel):
    total_tenants: int
    active_tenants: int
    total_users: int
    total_conversations: int
    total_prompts: int
    recent_prompts_24h: int
    recent_conversations_24h: int
