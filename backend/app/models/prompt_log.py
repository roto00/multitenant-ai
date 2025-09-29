from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, JSON, Float
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.core.database import Base

class PromptLog(Base):
    __tablename__ = "prompt_logs"

    id = Column(Integer, primary_key=True, index=True)
    
    # Relationships
    tenant_id = Column(Integer, ForeignKey("tenants.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Can be null for system prompts
    
    # Prompt details
    prompt_text = Column(Text, nullable=False)
    response_text = Column(Text)
    model_used = Column(String(100), nullable=False)
    
    # Performance metrics
    input_tokens = Column(Integer)
    output_tokens = Column(Integer)
    total_tokens = Column(Integer)
    latency_ms = Column(Float)
    cost_usd = Column(Float)
    
    # Request metadata
    request_id = Column(String(255), unique=True, index=True)
    user_agent = Column(String(500))
    ip_address = Column(String(45))
    
    # Response metadata
    status_code = Column(Integer)
    error_message = Column(Text)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    tenant = relationship("Tenant", back_populates="prompt_logs")
