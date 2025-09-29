from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta
import structlog

from app.core.database import get_db
from app.core.auth import get_current_admin_user
from app.schemas.admin import (
    PromptLogResponse, 
    TenantStatsResponse, 
    UsageStatsResponse,
    SystemStatsResponse
)
from app.models.prompt_log import PromptLog
from app.models.tenant import Tenant
from app.models.user import User
from app.models.conversation import Conversation
from app.services.rag_service import RAGService

logger = structlog.get_logger()
router = APIRouter()

rag_service = RAGService()

@router.get("/prompt-logs", response_model=List[PromptLogResponse])
async def get_prompt_logs(
    req: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user),
    tenant_id: Optional[int] = None,
    user_id: Optional[int] = None,
    model: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    limit: int = 100,
    offset: int = 0
):
    """Get prompt logs for administrative monitoring"""
    
    query = db.query(PromptLog)
    
    # Filter by tenant if specified
    if tenant_id:
        query = query.filter(PromptLog.tenant_id == tenant_id)
    
    # Filter by user if specified
    if user_id:
        query = query.filter(PromptLog.user_id == user_id)
    
    # Filter by model if specified
    if model:
        query = query.filter(PromptLog.model_used == model)
    
    # Filter by date range
    if start_date:
        query = query.filter(PromptLog.created_at >= start_date)
    if end_date:
        query = query.filter(PromptLog.created_at <= end_date)
    
    # Order by most recent first
    query = query.order_by(PromptLog.created_at.desc())
    
    # Apply pagination
    logs = query.offset(offset).limit(limit).all()
    
    return [
        PromptLogResponse(
            id=log.id,
            tenant_id=log.tenant_id,
            user_id=log.user_id,
            prompt_text=log.prompt_text,
            response_text=log.response_text,
            model_used=log.model_used,
            input_tokens=log.input_tokens,
            output_tokens=log.output_tokens,
            total_tokens=log.total_tokens,
            latency_ms=log.latency_ms,
            cost_usd=log.cost_usd,
            request_id=log.request_id,
            status_code=log.status_code,
            error_message=log.error_message,
            created_at=log.created_at
        )
        for log in logs
    ]

@router.get("/tenant-stats", response_model=List[TenantStatsResponse])
async def get_tenant_stats(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user)
):
    """Get statistics for all tenants"""
    
    tenants = db.query(Tenant).all()
    stats = []
    
    for tenant in tenants:
        # Get user count
        user_count = db.query(User).filter(User.tenant_id == tenant.id).count()
        
        # Get conversation count
        conversation_count = db.query(Conversation).filter(
            Conversation.tenant_id == tenant.id
        ).count()
        
        # Get prompt log count
        prompt_count = db.query(PromptLog).filter(
            PromptLog.tenant_id == tenant.id
        ).count()
        
        # Get total cost
        total_cost = db.query(PromptLog).filter(
            PromptLog.tenant_id == tenant.id,
            PromptLog.cost_usd.isnot(None)
        ).with_entities(
            db.func.sum(PromptLog.cost_usd)
        ).scalar() or 0
        
        # Get RAG stats
        rag_stats = await rag_service.get_collection_stats(tenant.name)
        
        stats.append(TenantStatsResponse(
            tenant_id=tenant.id,
            tenant_name=tenant.name,
            display_name=tenant.display_name,
            is_active=tenant.is_active,
            user_count=user_count,
            conversation_count=conversation_count,
            prompt_count=prompt_count,
            total_cost=total_cost,
            rag_document_count=rag_stats.get("document_count", 0),
            created_at=tenant.created_at
        ))
    
    return stats

@router.get("/usage-stats", response_model=UsageStatsResponse)
async def get_usage_stats(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user),
    days: int = 30
):
    """Get system-wide usage statistics"""
    
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    # Total prompts
    total_prompts = db.query(PromptLog).filter(
        PromptLog.created_at >= start_date
    ).count()
    
    # Successful prompts
    successful_prompts = db.query(PromptLog).filter(
        PromptLog.created_at >= start_date,
        PromptLog.status_code == 200
    ).count()
    
    # Total tokens
    total_tokens = db.query(PromptLog).filter(
        PromptLog.created_at >= start_date,
        PromptLog.total_tokens.isnot(None)
    ).with_entities(
        db.func.sum(PromptLog.total_tokens)
    ).scalar() or 0
    
    # Total cost
    total_cost = db.query(PromptLog).filter(
        PromptLog.created_at >= start_date,
        PromptLog.cost_usd.isnot(None)
    ).with_entities(
        db.func.sum(PromptLog.cost_usd)
    ).scalar() or 0
    
    # Average latency
    avg_latency = db.query(PromptLog).filter(
        PromptLog.created_at >= start_date,
        PromptLog.latency_ms.isnot(None)
    ).with_entities(
        db.func.avg(PromptLog.latency_ms)
    ).scalar() or 0
    
    # Model usage breakdown
    model_usage = db.query(
        PromptLog.model_used,
        db.func.count(PromptLog.id).label('count'),
        db.func.sum(PromptLog.cost_usd).label('cost')
    ).filter(
        PromptLog.created_at >= start_date
    ).group_by(PromptLog.model_used).all()
    
    return UsageStatsResponse(
        period_days=days,
        total_prompts=total_prompts,
        successful_prompts=successful_prompts,
        success_rate=successful_prompts / total_prompts if total_prompts > 0 else 0,
        total_tokens=total_tokens,
        total_cost=total_cost,
        average_latency_ms=avg_latency,
        model_usage=[
            {
                "model": usage.model_used,
                "count": usage.count,
                "cost": usage.cost or 0
            }
            for usage in model_usage
        ]
    )

@router.get("/system-stats", response_model=SystemStatsResponse)
async def get_system_stats(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user)
):
    """Get overall system statistics"""
    
    # Total counts
    total_tenants = db.query(Tenant).count()
    active_tenants = db.query(Tenant).filter(Tenant.is_active == True).count()
    total_users = db.query(User).count()
    total_conversations = db.query(Conversation).count()
    total_prompts = db.query(PromptLog).count()
    
    # Recent activity (last 24 hours)
    recent_cutoff = datetime.utcnow() - timedelta(hours=24)
    recent_prompts = db.query(PromptLog).filter(
        PromptLog.created_at >= recent_cutoff
    ).count()
    
    recent_conversations = db.query(Conversation).filter(
        Conversation.created_at >= recent_cutoff
    ).count()
    
    return SystemStatsResponse(
        total_tenants=total_tenants,
        active_tenants=active_tenants,
        total_users=total_users,
        total_conversations=total_conversations,
        total_prompts=total_prompts,
        recent_prompts_24h=recent_prompts,
        recent_conversations_24h=recent_conversations
    )

@router.get("/prompt-logs/{log_id}", response_model=PromptLogResponse)
async def get_prompt_log(
    log_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user)
):
    """Get a specific prompt log"""
    
    log = db.query(PromptLog).filter(PromptLog.id == log_id).first()
    if not log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prompt log not found"
        )
    
    return PromptLogResponse(
        id=log.id,
        tenant_id=log.tenant_id,
        user_id=log.user_id,
        prompt_text=log.prompt_text,
        response_text=log.response_text,
        model_used=log.model_used,
        input_tokens=log.input_tokens,
        output_tokens=log.output_tokens,
        total_tokens=log.total_tokens,
        latency_ms=log.latency_ms,
        cost_usd=log.cost_usd,
        request_id=log.request_id,
        status_code=log.status_code,
        error_message=log.error_message,
        created_at=log.created_at
    )
