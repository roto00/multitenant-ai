from pydantic import BaseModel
from typing import Optional, Dict, Any

class DocumentResponse(BaseModel):
    id: str
    title: str
    content: str
    metadata: Dict[str, Any]
    created_at: str

class SearchResponse(BaseModel):
    id: str
    content: str
    metadata: Dict[str, Any]
    similarity: float

class CollectionStatsResponse(BaseModel):
    tenant_id: str
    document_count: int
    collection_name: str
