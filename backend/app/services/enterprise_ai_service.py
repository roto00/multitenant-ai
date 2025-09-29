import asyncio
import boto3
import json
import time
import uuid
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
import structlog
from concurrent.futures import ThreadPoolExecutor
import aiohttp
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.enterprise_config import enterprise_settings
from app.services.rag_service import RAGService
from app.core.exceptions import AIServiceError
from app.services.rate_limiter import EnterpriseRateLimiter

logger = structlog.get_logger()

@dataclass
class EnterpriseAIResponse:
    content: str
    model_used: str
    input_tokens: int
    output_tokens: int
    total_tokens: int
    latency_ms: float
    cost_usd: float
    request_id: str
    tenant_id: str
    user_id: Optional[int]
    processing_time_ms: float
    queue_time_ms: float

class EnterpriseAIService:
    """Enterprise-scale AI service with advanced features for multi-tenant platform"""
    
    def __init__(self):
        self.bedrock_client = boto3.client(
            'bedrock-runtime',
            region_name=enterprise_settings.BEDROCK_REGION,
            aws_access_key_id=enterprise_settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=enterprise_settings.AWS_SECRET_ACCESS_KEY
        )
        self.rag_service = RAGService()
        self.rate_limiter = EnterpriseRateLimiter()
        
        # Thread pool for concurrent requests
        self.executor = ThreadPoolExecutor(max_workers=enterprise_settings.BEDROCK_MAX_CONCURRENT_REQUESTS)
        
        # Request queue for load balancing
        self.request_queue = asyncio.Queue(maxsize=1000)
        
        # Model configurations with enterprise features
        self.model_configs = {
            "anthropic.claude-3-sonnet-20240229-v1:0": {
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.003,
                "cost_per_1k_output": 0.015,
                "max_concurrent": 50,
                "priority": 1
            },
            "anthropic.claude-3-haiku-20240307-v1:0": {
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.00025,
                "cost_per_1k_output": 0.00125,
                "max_concurrent": 100,
                "priority": 2
            },
            "meta.llama-2-70b-chat-v1": {
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.00165,
                "cost_per_1k_output": 0.00219,
                "max_concurrent": 30,
                "priority": 3
            },
            "meta.llama-2-13b-chat-v1": {
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.00075,
                "cost_per_1k_output": 0.001,
                "max_concurrent": 50,
                "priority": 4
            }
        }
        
        # Performance metrics
        self.metrics = {
            "total_requests": 0,
            "successful_requests": 0,
            "failed_requests": 0,
            "average_latency": 0.0,
            "total_cost": 0.0
        }
    
    async def generate_response(
        self,
        prompt: str,
        model: str,
        tenant_id: str,
        user_id: Optional[int] = None,
        conversation_history: Optional[List[Dict]] = None,
        use_rag: bool = True,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        priority: int = 1,
        timeout: int = 300
    ) -> EnterpriseAIResponse:
        """Generate AI response with enterprise features"""
        
        request_id = str(uuid.uuid4())
        start_time = time.time()
        queue_start_time = time.time()
        
        try:
            # Check rate limits
            if not await self.rate_limiter.check_enterprise_rate_limit(
                tenant_id, user_id, model
            ):
                raise AIServiceError("Rate limit exceeded")
            
            # Get model configuration
            model_config = self.model_configs.get(model, self.model_configs["anthropic.claude-3-sonnet-20240229-v1:0"])
            
            # Check concurrent request limits
            if not await self._check_concurrent_limits(model, model_config):
                # Queue the request if at limit
                await self.request_queue.put({
                    "prompt": prompt,
                    "model": model,
                    "tenant_id": tenant_id,
                    "user_id": user_id,
                    "conversation_history": conversation_history,
                    "use_rag": use_rag,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                    "priority": priority,
                    "timeout": timeout,
                    "request_id": request_id
                })
                
                # Wait for processing
                queue_time = time.time() - queue_start_time
                result = await self._process_queued_request(request_id, timeout)
                result.queue_time_ms = queue_time * 1000
                return result
            
            # Process request immediately
            queue_time = time.time() - queue_start_time
            processing_start_time = time.time()
            
            # Enhance prompt with RAG if enabled
            enhanced_prompt = await self._enhance_prompt_with_rag(
                prompt, tenant_id, use_rag
            )
            
            # Build conversation context
            messages = await self._build_conversation_context(
                enhanced_prompt, conversation_history
            )
            
            # Generate response with retry logic
            response = await self._generate_with_retry(
                messages, model, model_config, temperature, max_tokens, timeout
            )
            
            # Calculate metrics
            processing_time = time.time() - processing_start_time
            total_time = time.time() - start_time
            
            # Parse response
            content, usage = self._parse_response(response, model)
            
            # Calculate cost
            cost_usd = self._calculate_cost(
                model, usage.get('input_tokens', 0), 
                usage.get('output_tokens', 0), model_config
            )
            
            # Update metrics
            self._update_metrics(processing_time, cost_usd, True)
            
            # Store interaction in RAG
            if use_rag and len(prompt) > 50:
                await self.rag_service.store_interaction(
                    prompt=prompt,
                    response=content,
                    tenant_id=tenant_id,
                    user_id=user_id
                )
            
            logger.info(
                "Enterprise AI response generated",
                request_id=request_id,
                model=model,
                tenant_id=tenant_id,
                user_id=user_id,
                input_tokens=usage.get('input_tokens', 0),
                output_tokens=usage.get('output_tokens', 0),
                processing_time_ms=processing_time * 1000,
                queue_time_ms=queue_time * 1000,
                cost_usd=cost_usd
            )
            
            return EnterpriseAIResponse(
                content=content,
                model_used=model,
                input_tokens=usage.get('input_tokens', 0),
                output_tokens=usage.get('output_tokens', 0),
                total_tokens=usage.get('input_tokens', 0) + usage.get('output_tokens', 0),
                latency_ms=total_time * 1000,
                cost_usd=cost_usd,
                request_id=request_id,
                tenant_id=tenant_id,
                user_id=user_id,
                processing_time_ms=processing_time * 1000,
                queue_time_ms=queue_time * 1000
            )
            
        except Exception as e:
            self._update_metrics(0, 0, False)
            logger.error(
                "Enterprise AI service error",
                request_id=request_id,
                error=str(e),
                model=model,
                tenant_id=tenant_id,
                user_id=user_id
            )
            raise AIServiceError(f"Failed to generate response: {str(e)}")
    
    async def _enhance_prompt_with_rag(
        self, prompt: str, tenant_id: str, use_rag: bool
    ) -> str:
        """Enhance prompt with RAG context"""
        if not use_rag:
            return prompt
        
        try:
            rag_context = await self.rag_service.get_relevant_context(
                query=prompt,
                tenant_id=tenant_id,
                limit=5
            )
            
            if rag_context:
                return f"""Context from knowledge base:
{rag_context}

User question: {prompt}

Please answer the user's question using the provided context when relevant."""
            
            return prompt
            
        except Exception as e:
            logger.warning(
                "RAG enhancement failed",
                error=str(e),
                tenant_id=tenant_id
            )
            return prompt
    
    async def _build_conversation_context(
        self, prompt: str, conversation_history: Optional[List[Dict]]
    ) -> List[Dict]:
        """Build conversation context for the model"""
        messages = []
        
        if conversation_history:
            # Limit to last 20 messages for performance
            for msg in conversation_history[-20:]:
                messages.append({
                    "role": msg.get("role", "user"),
                    "content": msg.get("content", "")
                })
        
        # Add current prompt
        messages.append({
            "role": "user",
            "content": prompt
        })
        
        return messages
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    async def _generate_with_retry(
        self, messages: List[Dict], model: str, model_config: Dict,
        temperature: Optional[float], max_tokens: Optional[int], timeout: int
    ) -> Dict:
        """Generate response with retry logic"""
        
        # Prepare request body
        if model.startswith("anthropic"):
            request_body = self._prepare_claude_request(
                messages, temperature or model_config["temperature"],
                max_tokens or model_config["max_tokens"]
            )
        elif model.startswith("meta"):
            request_body = self._prepare_llama_request(
                messages, temperature or model_config["temperature"],
                max_tokens or model_config["max_tokens"]
            )
        else:
            raise AIServiceError(f"Unsupported model: {model}")
        
        # Make request with timeout
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(
            self.executor,
            lambda: self.bedrock_client.invoke_model(
                modelId=model,
                body=json.dumps(request_body),
                contentType='application/json'
            )
        )
        
        return json.loads(response['body'].read())
    
    def _parse_response(self, response_body: Dict, model: str) -> Tuple[str, Dict]:
        """Parse response based on model type"""
        if model.startswith("anthropic"):
            content = response_body['content'][0]['text']
            usage = response_body.get('usage', {})
        else:
            content = response_body['generation']
            usage = response_body.get('usage', {})
        
        return content, usage
    
    def _calculate_cost(self, model: str, input_tokens: int, output_tokens: int, model_config: Dict) -> float:
        """Calculate cost based on token usage"""
        input_cost = (input_tokens / 1000) * model_config["cost_per_1k_input"]
        output_cost = (output_tokens / 1000) * model_config["cost_per_1k_output"]
        return round(input_cost + output_cost, 6)
    
    async def _check_concurrent_limits(self, model: str, model_config: Dict) -> bool:
        """Check if we can process the request immediately"""
        # This would integrate with a distributed counter (Redis)
        # For now, return True
        return True
    
    async def _process_queued_request(self, request_id: str, timeout: int) -> EnterpriseAIResponse:
        """Process a queued request"""
        # This would implement queue processing logic
        # For now, raise an error
        raise AIServiceError("Request queued but processing not implemented")
    
    def _update_metrics(self, processing_time: float, cost: float, success: bool):
        """Update performance metrics"""
        self.metrics["total_requests"] += 1
        if success:
            self.metrics["successful_requests"] += 1
        else:
            self.metrics["failed_requests"] += 1
        
        # Update average latency
        total_requests = self.metrics["total_requests"]
        current_avg = self.metrics["average_latency"]
        self.metrics["average_latency"] = (
            (current_avg * (total_requests - 1) + processing_time) / total_requests
        )
        
        self.metrics["total_cost"] += cost
    
    def _prepare_claude_request(self, messages: List[Dict], temperature: float, max_tokens: int) -> Dict:
        """Prepare request body for Claude models"""
        return {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": max_tokens,
            "temperature": temperature,
            "messages": messages
        }
    
    def _prepare_llama_request(self, messages: List[Dict], temperature: float, max_tokens: int) -> Dict:
        """Prepare request body for Llama models"""
        prompt = ""
        for msg in messages:
            role = msg["role"]
            content = msg["content"]
            if role == "user":
                prompt += f"Human: {content}\n\n"
            elif role == "assistant":
                prompt += f"Assistant: {content}\n\n"
        
        prompt += "Assistant:"
        
        return {
            "prompt": prompt,
            "max_gen_len": max_tokens,
            "temperature": temperature,
            "top_p": 0.9
        }
    
    def get_metrics(self) -> Dict:
        """Get current performance metrics"""
        return self.metrics.copy()
    
    def get_available_models(self) -> List[Dict]:
        """Get list of available models with enterprise configurations"""
        return [
            {
                "id": model_id,
                "name": model_id.split(".")[-1].replace("-", " ").title(),
                "provider": model_id.split(".")[0],
                "config": config,
                "max_concurrent": config["max_concurrent"],
                "priority": config["priority"]
            }
            for model_id, config in self.model_configs.items()
        ]
    
    async def batch_generate(
        self, requests: List[Dict], tenant_id: str
    ) -> List[EnterpriseAIResponse]:
        """Generate multiple responses in batch"""
        tasks = []
        for req in requests:
            task = self.generate_response(
                prompt=req["prompt"],
                model=req.get("model", "anthropic.claude-3-haiku-20240307-v1:0"),
                tenant_id=tenant_id,
                user_id=req.get("user_id"),
                conversation_history=req.get("conversation_history"),
                use_rag=req.get("use_rag", True),
                temperature=req.get("temperature"),
                max_tokens=req.get("max_tokens"),
                priority=req.get("priority", 2)
            )
            tasks.append(task)
        
        return await asyncio.gather(*tasks, return_exceptions=True)
