import chromadb
from chromadb.config import Settings
import uuid
from typing import List, Dict, Optional, Any
import structlog
from sentence_transformers import SentenceTransformer
import os

from app.core.config import settings

logger = structlog.get_logger()

class RAGService:
    """Service for Retrieval-Augmented Generation using ChromaDB"""
    
    def __init__(self):
        # Initialize ChromaDB
        self.chroma_client = chromadb.PersistentClient(
            path=settings.CHROMA_PERSIST_DIRECTORY,
            settings=Settings(
                anonymized_telemetry=False,
                allow_reset=True
            )
        )
        
        # Initialize sentence transformer for embeddings
        self.embedder = SentenceTransformer('all-MiniLM-L6-v2')
        
        # Collection cache
        self._collections = {}
    
    def _get_collection(self, tenant_id: str):
        """Get or create collection for tenant"""
        if tenant_id not in self._collections:
            try:
                collection = self.chroma_client.get_collection(f"tenant_{tenant_id}")
                self._collections[tenant_id] = collection
            except:
                # Create new collection if it doesn't exist
                collection = self.chroma_client.create_collection(
                    name=f"tenant_{tenant_id}",
                    metadata={"tenant_id": tenant_id}
                )
                self._collections[tenant_id] = collection
        
        return self._collections[tenant_id]
    
    async def store_interaction(
        self,
        prompt: str,
        response: str,
        tenant_id: str,
        user_id: Optional[int] = None,
        metadata: Optional[Dict] = None
    ):
        """Store a prompt-response interaction in the vector database"""
        try:
            collection = self._get_collection(tenant_id)
            
            # Create document ID
            doc_id = str(uuid.uuid4())
            
            # Combine prompt and response for better retrieval
            combined_text = f"Question: {prompt}\nAnswer: {response}"
            
            # Prepare metadata
            doc_metadata = {
                "tenant_id": tenant_id,
                "user_id": user_id,
                "type": "interaction",
                "prompt": prompt[:500],  # Truncate for storage
                "response": response[:500]  # Truncate for storage
            }
            
            if metadata:
                doc_metadata.update(metadata)
            
            # Add to collection
            collection.add(
                documents=[combined_text],
                metadatas=[doc_metadata],
                ids=[doc_id]
            )
            
            logger.info(
                "Stored interaction in RAG",
                tenant_id=tenant_id,
                user_id=user_id,
                doc_id=doc_id
            )
            
        except Exception as e:
            logger.error(
                "Failed to store interaction in RAG",
                tenant_id=tenant_id,
                error=str(e)
            )
    
    async def store_document(
        self,
        content: str,
        tenant_id: str,
        title: Optional[str] = None,
        metadata: Optional[Dict] = None
    ):
        """Store a document in the vector database"""
        try:
            collection = self._get_collection(tenant_id)
            
            # Create document ID
            doc_id = str(uuid.uuid4())
            
            # Prepare metadata
            doc_metadata = {
                "tenant_id": tenant_id,
                "type": "document",
                "title": title or "Untitled Document"
            }
            
            if metadata:
                doc_metadata.update(metadata)
            
            # Add to collection
            collection.add(
                documents=[content],
                metadatas=[doc_metadata],
                ids=[doc_id]
            )
            
            logger.info(
                "Stored document in RAG",
                tenant_id=tenant_id,
                doc_id=doc_id,
                title=title
            )
            
        except Exception as e:
            logger.error(
                "Failed to store document in RAG",
                tenant_id=tenant_id,
                error=str(e)
            )
    
    async def get_relevant_context(
        self,
        query: str,
        tenant_id: str,
        limit: int = 5,
        similarity_threshold: float = 0.7
    ) -> Optional[str]:
        """Retrieve relevant context for a query"""
        try:
            collection = self._get_collection(tenant_id)
            
            # Query the collection
            results = collection.query(
                query_texts=[query],
                n_results=limit,
                where={"tenant_id": tenant_id}
            )
            
            if not results['documents'] or not results['documents'][0]:
                return None
            
            # Filter by similarity threshold
            relevant_docs = []
            for i, distance in enumerate(results['distances'][0]):
                similarity = 1 - distance  # Convert distance to similarity
                if similarity >= similarity_threshold:
                    relevant_docs.append(results['documents'][0][i])
            
            if not relevant_docs:
                return None
            
            # Combine relevant documents
            context = "\n\n".join(relevant_docs)
            
            logger.info(
                "Retrieved context from RAG",
                tenant_id=tenant_id,
                query_length=len(query),
                context_length=len(context),
                num_docs=len(relevant_docs)
            )
            
            return context
            
        except Exception as e:
            logger.error(
                "Failed to retrieve context from RAG",
                tenant_id=tenant_id,
                error=str(e)
            )
            return None
    
    async def search_documents(
        self,
        query: str,
        tenant_id: str,
        limit: int = 10,
        doc_type: Optional[str] = None
    ) -> List[Dict]:
        """Search documents in the vector database"""
        try:
            collection = self._get_collection(tenant_id)
            
            # Build where clause
            where_clause = {"tenant_id": tenant_id}
            if doc_type:
                where_clause["type"] = doc_type
            
            # Query the collection
            results = collection.query(
                query_texts=[query],
                n_results=limit,
                where=where_clause
            )
            
            if not results['documents'] or not results['documents'][0]:
                return []
            
            # Format results
            search_results = []
            for i, doc in enumerate(results['documents'][0]):
                search_results.append({
                    "id": results['ids'][0][i],
                    "content": doc,
                    "metadata": results['metadatas'][0][i],
                    "similarity": 1 - results['distances'][0][i]
                })
            
            logger.info(
                "Searched documents in RAG",
                tenant_id=tenant_id,
                query=query,
                results_count=len(search_results)
            )
            
            return search_results
            
        except Exception as e:
            logger.error(
                "Failed to search documents in RAG",
                tenant_id=tenant_id,
                error=str(e)
            )
            return []
    
    async def delete_document(self, doc_id: str, tenant_id: str):
        """Delete a document from the vector database"""
        try:
            collection = self._get_collection(tenant_id)
            collection.delete(ids=[doc_id])
            
            logger.info(
                "Deleted document from RAG",
                tenant_id=tenant_id,
                doc_id=doc_id
            )
            
        except Exception as e:
            logger.error(
                "Failed to delete document from RAG",
                tenant_id=tenant_id,
                doc_id=doc_id,
                error=str(e)
            )
    
    async def get_collection_stats(self, tenant_id: str) -> Dict:
        """Get statistics about the tenant's collection"""
        try:
            collection = self._get_collection(tenant_id)
            count = collection.count()
            
            return {
                "tenant_id": tenant_id,
                "document_count": count,
                "collection_name": f"tenant_{tenant_id}"
            }
            
        except Exception as e:
            logger.error(
                "Failed to get collection stats",
                tenant_id=tenant_id,
                error=str(e)
            )
            return {
                "tenant_id": tenant_id,
                "document_count": 0,
                "error": str(e)
            }
