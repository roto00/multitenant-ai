from fastapi import APIRouter

from app.api.v1.endpoints import chat, admin, tenants, rag

api_router = APIRouter()

api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(tenants.router, prefix="/tenants", tags=["tenants"])
api_router.include_router(rag.router, prefix="/rag", tags=["rag"])
