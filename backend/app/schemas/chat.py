from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=10000)
    model: Optional[str] = None
    conversation_id: Optional[int] = None
    conversation_history: Optional[List[Dict[str, str]]] = None
    use_rag: bool = True
    temperature: Optional[float] = Field(None, ge=0.0, le=1.0)
    max_tokens: Optional[int] = Field(None, ge=1, le=8000)

class ChatResponse(BaseModel):
    response: str
    conversation_id: int
    model_used: str
    tokens_used: int
    latency_ms: float
    cost_usd: float
    request_id: str

class ConversationCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)

class ConversationResponse(BaseModel):
    id: int
    title: str
    created_at: datetime
    updated_at: datetime
    message_count: int
    messages: Optional[List[Dict[str, str]]] = None
