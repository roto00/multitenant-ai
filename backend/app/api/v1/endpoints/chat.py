from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from typing import List, Optional
import structlog

from app.core.database import get_db
from app.core.exceptions import TenantNotFoundError, RateLimitExceededError
from app.services.ai_service import AIService
from app.services.rate_limiter import RateLimiter
from app.schemas.chat import ChatRequest, ChatResponse, ConversationCreate, ConversationResponse
from app.models.tenant import Tenant
from app.models.conversation import Conversation
from app.models.prompt_log import PromptLog
from app.core.auth import get_current_user

logger = structlog.get_logger()
router = APIRouter()

ai_service = AIService()
rate_limiter = RateLimiter()

@router.post("/", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    req: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Send a message and get AI response"""
    
    # Get tenant from request state
    tenant_id = getattr(req.state, "tenant_id", None)
    if not tenant_id:
        raise TenantNotFoundError("No tenant specified")
    
    # Get tenant from database
    tenant = db.query(Tenant).filter(Tenant.name == tenant_id).first()
    if not tenant:
        raise TenantNotFoundError(tenant_id)
    
    # Check rate limiting
    if not await rate_limiter.check_rate_limit(tenant_id, current_user.id):
        raise RateLimitExceededError()
    
    try:
        # Generate AI response
        ai_response = await ai_service.generate_response(
            prompt=request.message,
            model=request.model or tenant.default_model,
            tenant_id=tenant_id,
            user_id=current_user.id,
            conversation_history=request.conversation_history,
            use_rag=request.use_rag,
            temperature=request.temperature,
            max_tokens=request.max_tokens
        )
        
        # Log the interaction
        prompt_log = PromptLog(
            tenant_id=tenant.id,
            user_id=current_user.id,
            prompt_text=request.message,
            response_text=ai_response.content,
            model_used=ai_response.model_used,
            input_tokens=ai_response.input_tokens,
            output_tokens=ai_response.output_tokens,
            total_tokens=ai_response.total_tokens,
            latency_ms=ai_response.latency_ms,
            cost_usd=ai_response.cost_usd,
            request_id=ai_response.request_id,
            user_agent=req.headers.get("user-agent"),
            ip_address=req.client.host if req.client else None,
            status_code=200
        )
        db.add(prompt_log)
        db.commit()
        
        # Create or update conversation if conversation_id provided
        conversation = None
        if request.conversation_id:
            conversation = db.query(Conversation).filter(
                Conversation.id == request.conversation_id,
                Conversation.tenant_id == tenant.id,
                Conversation.user_id == current_user.id
            ).first()
        
        if conversation:
            # Update existing conversation
            conversation.messages.append({
                "role": "user",
                "content": request.message
            })
            conversation.messages.append({
                "role": "assistant",
                "content": ai_response.content
            })
            conversation.model_used = ai_response.model_used
            conversation.temperature = request.temperature
            conversation.max_tokens = request.max_tokens
        else:
            # Create new conversation
            conversation = Conversation(
                tenant_id=tenant.id,
                user_id=current_user.id,
                title=request.message[:50] + "..." if len(request.message) > 50 else request.message,
                messages=[
                    {"role": "user", "content": request.message},
                    {"role": "assistant", "content": ai_response.content}
                ],
                model_used=ai_response.model_used,
                temperature=request.temperature,
                max_tokens=request.max_tokens
            )
            db.add(conversation)
        
        db.commit()
        db.refresh(conversation)
        
        return ChatResponse(
            response=ai_response.content,
            conversation_id=conversation.id,
            model_used=ai_response.model_used,
            tokens_used=ai_response.total_tokens,
            latency_ms=ai_response.latency_ms,
            cost_usd=ai_response.cost_usd,
            request_id=ai_response.request_id
        )
        
    except Exception as e:
        logger.error(
            "Chat error",
            error=str(e),
            tenant_id=tenant_id,
            user_id=current_user.id
        )
        
        # Log failed request
        prompt_log = PromptLog(
            tenant_id=tenant.id,
            user_id=current_user.id,
            prompt_text=request.message,
            model_used=request.model or tenant.default_model,
            request_id=ai_response.request_id if 'ai_response' in locals() else None,
            user_agent=req.headers.get("user-agent"),
            ip_address=req.client.host if req.client else None,
            status_code=500,
            error_message=str(e)
        )
        db.add(prompt_log)
        db.commit()
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate response"
        )

@router.get("/conversations", response_model=List[ConversationResponse])
async def get_conversations(
    req: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
    limit: int = 20,
    offset: int = 0
):
    """Get user's conversations"""
    
    tenant_id = getattr(req.state, "tenant_id", None)
    if not tenant_id:
        raise TenantNotFoundError("No tenant specified")
    
    tenant = db.query(Tenant).filter(Tenant.name == tenant_id).first()
    if not tenant:
        raise TenantNotFoundError(tenant_id)
    
    conversations = db.query(Conversation).filter(
        Conversation.tenant_id == tenant.id,
        Conversation.user_id == current_user.id
    ).order_by(Conversation.updated_at.desc()).offset(offset).limit(limit).all()
    
    return [
        ConversationResponse(
            id=conv.id,
            title=conv.title,
            created_at=conv.created_at,
            updated_at=conv.updated_at,
            message_count=len(conv.messages) if conv.messages else 0
        )
        for conv in conversations
    ]

@router.get("/conversations/{conversation_id}", response_model=ConversationResponse)
async def get_conversation(
    conversation_id: int,
    req: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get a specific conversation"""
    
    tenant_id = getattr(req.state, "tenant_id", None)
    if not tenant_id:
        raise TenantNotFoundError("No tenant specified")
    
    tenant = db.query(Tenant).filter(Tenant.name == tenant_id).first()
    if not tenant:
        raise TenantNotFoundError(tenant_id)
    
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.tenant_id == tenant.id,
        Conversation.user_id == current_user.id
    ).first()
    
    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )
    
    return ConversationResponse(
        id=conversation.id,
        title=conversation.title,
        created_at=conversation.created_at,
        updated_at=conversation.updated_at,
        message_count=len(conversation.messages) if conversation.messages else 0,
        messages=conversation.messages
    )

@router.get("/models")
async def get_available_models():
    """Get available AI models"""
    return ai_service.get_available_models()
