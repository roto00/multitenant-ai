from fastapi import APIRouter, Depends, HTTPException, Request, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
import structlog

from app.core.database import get_db
from app.core.auth import get_current_user
from app.schemas.rag import DocumentResponse, SearchResponse, CollectionStatsResponse
from app.services.rag_service import RAGService
from app.models.tenant import Tenant

logger = structlog.get_logger()
router = APIRouter()

rag_service = RAGService()

@router.post("/documents")
async def upload_document(
    title: str,
    content: str,
    req: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Upload a document to the RAG system"""
    
    tenant_id = getattr(req.state, "tenant_id", None)
    if not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No tenant specified"
        )
    
    tenant = db.query(Tenant).filter(Tenant.name == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found"
        )
    
    try:
        await rag_service.store_document(
            content=content,
            tenant_id=tenant_id,
            title=title,
            metadata={
                "uploaded_by": current_user.id,
                "uploaded_at": "now"
            }
        )
        
        logger.info(
            "Document uploaded to RAG",
            tenant_id=tenant_id,
            user_id=current_user.id,
            title=title
        )
        
        return {"message": "Document uploaded successfully"}
        
    except Exception as e:
        logger.error(
            "Failed to upload document",
            tenant_id=tenant_id,
            user_id=current_user.id,
            error=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload document"
        )

@router.get("/search", response_model=List[SearchResponse])
async def search_documents(
    query: str,
    req: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
    limit: int = 10,
    doc_type: Optional[str] = None
):
    """Search documents in the RAG system"""
    
    tenant_id = getattr(req.state, "tenant_id", None)
    if not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No tenant specified"
        )
    
    tenant = db.query(Tenant).filter(Tenant.name == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found"
        )
    
    try:
        results = await rag_service.search_documents(
            query=query,
            tenant_id=tenant_id,
            limit=limit,
            doc_type=doc_type
        )
        
        return [
            SearchResponse(
                id=result["id"],
                content=result["content"],
                metadata=result["metadata"],
                similarity=result["similarity"]
            )
            for result in results
        ]
        
    except Exception as e:
        logger.error(
            "Failed to search documents",
            tenant_id=tenant_id,
            user_id=current_user.id,
            error=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to search documents"
        )

@router.get("/stats", response_model=CollectionStatsResponse)
async def get_collection_stats(
    req: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get RAG collection statistics"""
    
    tenant_id = getattr(req.state, "tenant_id", None)
    if not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No tenant specified"
        )
    
    tenant = db.query(Tenant).filter(Tenant.name == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found"
        )
    
    try:
        stats = await rag_service.get_collection_stats(tenant_id)
        
        return CollectionStatsResponse(
            tenant_id=stats["tenant_id"],
            document_count=stats["document_count"],
            collection_name=stats["collection_name"]
        )
        
    except Exception as e:
        logger.error(
            "Failed to get collection stats",
            tenant_id=tenant_id,
            user_id=current_user.id,
            error=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get collection stats"
        )

@router.delete("/documents/{doc_id}")
async def delete_document(
    doc_id: str,
    req: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Delete a document from the RAG system"""
    
    tenant_id = getattr(req.state, "tenant_id", None)
    if not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No tenant specified"
        )
    
    tenant = db.query(Tenant).filter(Tenant.name == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found"
        )
    
    try:
        await rag_service.delete_document(doc_id, tenant_id)
        
        logger.info(
            "Document deleted from RAG",
            tenant_id=tenant_id,
            user_id=current_user.id,
            doc_id=doc_id
        )
        
        return {"message": "Document deleted successfully"}
        
    except Exception as e:
        logger.error(
            "Failed to delete document",
            tenant_id=tenant_id,
            user_id=current_user.id,
            doc_id=doc_id,
            error=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete document"
        )
