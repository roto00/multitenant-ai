from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from typing import List
import structlog

from app.core.database import get_db
from app.core.auth import get_current_admin_user
from app.schemas.tenant import TenantCreate, TenantUpdate, TenantResponse
from app.models.tenant import Tenant

logger = structlog.get_logger()
router = APIRouter()

@router.get("/", response_model=List[TenantResponse])
async def get_tenants(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user)
):
    """Get all tenants (admin only)"""
    
    tenants = db.query(Tenant).all()
    return [
        TenantResponse(
            id=tenant.id,
            name=tenant.name,
            domain=tenant.domain,
            display_name=tenant.display_name,
            description=tenant.description,
            is_active=tenant.is_active,
            default_model=tenant.default_model,
            max_tokens=tenant.max_tokens,
            temperature=tenant.temperature,
            rate_limit_per_minute=tenant.rate_limit_per_minute,
            rate_limit_per_hour=tenant.rate_limit_per_hour,
            created_at=tenant.created_at,
            updated_at=tenant.updated_at
        )
        for tenant in tenants
    ]

@router.post("/", response_model=TenantResponse)
async def create_tenant(
    tenant_data: TenantCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user)
):
    """Create a new tenant (admin only)"""
    
    # Check if tenant name already exists
    existing_tenant = db.query(Tenant).filter(Tenant.name == tenant_data.name).first()
    if existing_tenant:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tenant name already exists"
        )
    
    # Check if domain already exists
    existing_domain = db.query(Tenant).filter(Tenant.domain == tenant_data.domain).first()
    if existing_domain:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Domain already exists"
        )
    
    # Create new tenant
    tenant = Tenant(
        name=tenant_data.name,
        domain=tenant_data.domain,
        display_name=tenant_data.display_name,
        description=tenant_data.description,
        config=tenant_data.config or {},
        is_active=tenant_data.is_active,
        default_model=tenant_data.default_model,
        max_tokens=tenant_data.max_tokens,
        temperature=tenant_data.temperature,
        rate_limit_per_minute=tenant_data.rate_limit_per_minute,
        rate_limit_per_hour=tenant_data.rate_limit_per_hour
    )
    
    db.add(tenant)
    db.commit()
    db.refresh(tenant)
    
    logger.info(
        "Tenant created",
        tenant_id=tenant.id,
        tenant_name=tenant.name,
        created_by=current_user.id
    )
    
    return TenantResponse(
        id=tenant.id,
        name=tenant.name,
        domain=tenant.domain,
        display_name=tenant.display_name,
        description=tenant.description,
        is_active=tenant.is_active,
        default_model=tenant.default_model,
        max_tokens=tenant.max_tokens,
        temperature=tenant.temperature,
        rate_limit_per_minute=tenant.rate_limit_per_minute,
        rate_limit_per_hour=tenant.rate_limit_per_hour,
        created_at=tenant.created_at,
        updated_at=tenant.updated_at
    )

@router.get("/{tenant_id}", response_model=TenantResponse)
async def get_tenant(
    tenant_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user)
):
    """Get a specific tenant (admin only)"""
    
    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found"
        )
    
    return TenantResponse(
        id=tenant.id,
        name=tenant.name,
        domain=tenant.domain,
        display_name=tenant.display_name,
        description=tenant.description,
        is_active=tenant.is_active,
        default_model=tenant.default_model,
        max_tokens=tenant.max_tokens,
        temperature=tenant.temperature,
        rate_limit_per_minute=tenant.rate_limit_per_minute,
        rate_limit_per_hour=tenant.rate_limit_per_hour,
        created_at=tenant.created_at,
        updated_at=tenant.updated_at
    )

@router.put("/{tenant_id}", response_model=TenantResponse)
async def update_tenant(
    tenant_id: int,
    tenant_data: TenantUpdate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user)
):
    """Update a tenant (admin only)"""
    
    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found"
        )
    
    # Update fields
    update_data = tenant_data.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(tenant, field, value)
    
    db.commit()
    db.refresh(tenant)
    
    logger.info(
        "Tenant updated",
        tenant_id=tenant.id,
        tenant_name=tenant.name,
        updated_by=current_user.id,
        updated_fields=list(update_data.keys())
    )
    
    return TenantResponse(
        id=tenant.id,
        name=tenant.name,
        domain=tenant.domain,
        display_name=tenant.display_name,
        description=tenant.description,
        is_active=tenant.is_active,
        default_model=tenant.default_model,
        max_tokens=tenant.max_tokens,
        temperature=tenant.temperature,
        rate_limit_per_minute=tenant.rate_limit_per_minute,
        rate_limit_per_hour=tenant.rate_limit_per_hour,
        created_at=tenant.created_at,
        updated_at=tenant.updated_at
    )

@router.delete("/{tenant_id}")
async def delete_tenant(
    tenant_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_admin_user)
):
    """Delete a tenant (admin only)"""
    
    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found"
        )
    
    # Soft delete by deactivating
    tenant.is_active = False
    db.commit()
    
    logger.info(
        "Tenant deactivated",
        tenant_id=tenant.id,
        tenant_name=tenant.name,
        deactivated_by=current_user.id
    )
    
    return {"message": "Tenant deactivated successfully"}
