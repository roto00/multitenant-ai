from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.core.database import Base

class Tenant(Base):
    __tablename__ = "tenants"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), unique=True, index=True, nullable=False)
    domain = Column(String(255), unique=True, index=True, nullable=False)
    display_name = Column(String(255), nullable=False)
    description = Column(Text)
    
    # Configuration
    config = Column(JSON, default=dict)
    is_active = Column(Boolean, default=True)
    
    # AI Model Configuration
    default_model = Column(String(100), default="anthropic.claude-3-sonnet-20240229-v1:0")
    max_tokens = Column(Integer, default=4000)
    temperature = Column(Integer, default=0.7)  # Stored as integer (0-100)
    
    # Rate limiting
    rate_limit_per_minute = Column(Integer, default=60)
    rate_limit_per_hour = Column(Integer, default=1000)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    users = relationship("User", back_populates="tenant")
    conversations = relationship("Conversation", back_populates="tenant")
    prompt_logs = relationship("PromptLog", back_populates="tenant")
