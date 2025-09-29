import asyncio
import boto3
import openai
import requests
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
class MultiProviderAIResponse:
    content: str
    provider: str
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

class MultiProviderAIService:
    """Multi-provider AI service supporting AWS Bedrock, OpenAI, HuggingFace, and custom models"""
    
    def __init__(self):
        # AWS Bedrock client
        self.bedrock_client = boto3.client(
            'bedrock-runtime',
            region_name=enterprise_settings.BEDROCK_REGION,
            aws_access_key_id=enterprise_settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=enterprise_settings.AWS_SECRET_ACCESS_KEY
        )
        
        # OpenAI client
        self.openai_client = openai.OpenAI(
            api_key=enterprise_settings.OPENAI_API_KEY
        )
        
        # HuggingFace client
        self.huggingface_client = None
        if enterprise_settings.HUGGINGFACE_API_KEY:
            self.huggingface_client = aiohttp.ClientSession(
                headers={"Authorization": f"Bearer {enterprise_settings.HUGGINGFACE_API_KEY}"}
            )
        
        self.rag_service = RAGService()
        self.rate_limiter = EnterpriseRateLimiter()
        
        # Thread pool for concurrent requests
        self.executor = ThreadPoolExecutor(max_workers=enterprise_settings.BEDROCK_MAX_CONCURRENT_REQUESTS)
        
        # Model configurations for different providers
        self.model_configs = {
            # AWS Bedrock Models
            "anthropic.claude-3-sonnet-20240229-v1:0": {
                "provider": "bedrock",
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.003,
                "cost_per_1k_output": 0.015,
                "max_concurrent": 50,
                "priority": 1
            },
            "anthropic.claude-3-haiku-20240307-v1:0": {
                "provider": "bedrock",
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.00025,
                "cost_per_1k_output": 0.00125,
                "max_concurrent": 100,
                "priority": 2
            },
            "meta.llama-2-70b-chat-v1": {
                "provider": "bedrock",
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.00165,
                "cost_per_1k_output": 0.00219,
                "max_concurrent": 30,
                "priority": 3
            },
            
            # OpenAI Models
            "gpt-4": {
                "provider": "openai",
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.03,
                "cost_per_1k_output": 0.06,
                "max_concurrent": 20,
                "priority": 1
            },
            "gpt-4-turbo": {
                "provider": "openai",
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.01,
                "cost_per_1k_output": 0.03,
                "max_concurrent": 30,
                "priority": 2
            },
            "gpt-3.5-turbo": {
                "provider": "openai",
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.0015,
                "cost_per_1k_output": 0.002,
                "max_concurrent": 50,
                "priority": 3
            },
            
            # HuggingFace Models
            "microsoft/DialoGPT-large": {
                "provider": "huggingface",
                "max_tokens": 1000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.0,  # Free tier
                "cost_per_1k_output": 0.0,
                "max_concurrent": 10,
                "priority": 4
            },
            "google/flan-t5-xxl": {
                "provider": "huggingface",
                "max_tokens": 1000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.0,
                "cost_per_1k_output": 0.0,
                "max_concurrent": 10,
                "priority": 4
            },
            
            # Custom Models (deployed on tenant clusters)
            "custom-tenant-model": {
                "provider": "custom",
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.0,  # No additional cost
                "cost_per_1k_output": 0.0,
                "max_concurrent": 5,
                "priority": 1
            }
        }
        
        # Performance metrics
        self.metrics = {
            "total_requests": 0,
            "successful_requests": 0,
            "failed_requests": 0,
            "average_latency": 0.0,
            "total_cost": 0.0,
            "provider_usage": {}
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
    ) -> MultiProviderAIResponse:
        """Generate AI response using the specified model and provider"""
        
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
            model_config = self.model_configs.get(model)
            if not model_config:
                raise AIServiceError(f"Unsupported model: {model}")
            
            # Check if model is available for tenant
            if not await self._check_tenant_model_access(tenant_id, model, model_config):
                raise AIServiceError(f"Model {model} not available for tenant {tenant_id}")
            
            # Enhance prompt with RAG if enabled
            enhanced_prompt = await self._enhance_prompt_with_rag(
                prompt, tenant_id, use_rag
            )
            
            # Build conversation context
            messages = await self._build_conversation_context(
                enhanced_prompt, conversation_history
            )
            
            # Generate response based on provider
            processing_start_time = time.time()
            
            if model_config["provider"] == "bedrock":
                response = await self._generate_bedrock_response(
                    messages, model, model_config, temperature, max_tokens, timeout
                )
            elif model_config["provider"] == "openai":
                response = await self._generate_openai_response(
                    messages, model, model_config, temperature, max_tokens, timeout
                )
            elif model_config["provider"] == "huggingface":
                response = await self._generate_huggingface_response(
                    messages, model, model_config, temperature, max_tokens, timeout
                )
            elif model_config["provider"] == "custom":
                response = await self._generate_custom_response(
                    messages, model, model_config, tenant_id, temperature, max_tokens, timeout
                )
            else:
                raise AIServiceError(f"Unsupported provider: {model_config['provider']}")
            
            # Calculate metrics
            processing_time = time.time() - processing_start_time
            total_time = time.time() - start_time
            queue_time = queue_start_time - start_time
            
            # Parse response
            content, usage = self._parse_response(response, model_config["provider"])
            
            # Calculate cost
            cost_usd = self._calculate_cost(
                model, usage.get('input_tokens', 0), 
                usage.get('output_tokens', 0), model_config
            )
            
            # Update metrics
            self._update_metrics(processing_time, cost_usd, True, model_config["provider"])
            
            # Store interaction in RAG (tenant-specific)
            if use_rag and len(prompt) > 50:
                await self.rag_service.store_interaction(
                    prompt=prompt,
                    response=content,
                    tenant_id=tenant_id,
                    user_id=user_id
                )
            
            logger.info(
                "Multi-provider AI response generated",
                request_id=request_id,
                provider=model_config["provider"],
                model=model,
                tenant_id=tenant_id,
                user_id=user_id,
                input_tokens=usage.get('input_tokens', 0),
                output_tokens=usage.get('output_tokens', 0),
                processing_time_ms=processing_time * 1000,
                queue_time_ms=queue_time * 1000,
                cost_usd=cost_usd
            )
            
            return MultiProviderAIResponse(
                content=content,
                provider=model_config["provider"],
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
            self._update_metrics(0, 0, False, model_config.get("provider", "unknown") if 'model_config' in locals() else "unknown")
            logger.error(
                "Multi-provider AI service error",
                request_id=request_id,
                error=str(e),
                model=model,
                tenant_id=tenant_id,
                user_id=user_id
            )
            raise AIServiceError(f"Failed to generate response: {str(e)}")
    
    async def _generate_bedrock_response(
        self, messages: List[Dict], model: str, model_config: Dict,
        temperature: Optional[float], max_tokens: Optional[int], timeout: int
    ) -> Dict:
        """Generate response using AWS Bedrock"""
        
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
            raise AIServiceError(f"Unsupported Bedrock model: {model}")
        
        # Make request
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
    
    async def _generate_openai_response(
        self, messages: List[Dict], model: str, model_config: Dict,
        temperature: Optional[float], max_tokens: Optional[int], timeout: int
    ) -> Dict:
        """Generate response using OpenAI"""
        
        # Convert messages to OpenAI format
        openai_messages = []
        for msg in messages:
            openai_messages.append({
                "role": msg["role"],
                "content": msg["content"]
            })
        
        # Make request
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(
            self.executor,
            lambda: self.openai_client.chat.completions.create(
                model=model,
                messages=openai_messages,
                temperature=temperature or model_config["temperature"],
                max_tokens=max_tokens or model_config["max_tokens"],
                timeout=timeout
            )
        )
        
        return {
            "content": response.choices[0].message.content,
            "usage": {
                "input_tokens": response.usage.prompt_tokens,
                "output_tokens": response.usage.completion_tokens,
                "total_tokens": response.usage.total_tokens
            }
        }
    
    async def _generate_huggingface_response(
        self, messages: List[Dict], model: str, model_config: Dict,
        temperature: Optional[float], max_tokens: Optional[int], timeout: int
    ) -> Dict:
        """Generate response using HuggingFace"""
        
        if not self.huggingface_client:
            raise AIServiceError("HuggingFace client not configured")
        
        # Prepare request
        prompt = self._messages_to_prompt(messages)
        
        payload = {
            "inputs": prompt,
            "parameters": {
                "temperature": temperature or model_config["temperature"],
                "max_length": max_tokens or model_config["max_tokens"],
                "return_full_text": False
            }
        }
        
        # Make request
        async with self.huggingface_client.post(
            f"https://api-inference.huggingface.co/models/{model}",
            json=payload,
            timeout=timeout
        ) as response:
            if response.status != 200:
                raise AIServiceError(f"HuggingFace API error: {response.status}")
            
            result = await response.json()
            
            return {
                "content": result[0]["generated_text"],
                "usage": {
                    "input_tokens": len(prompt.split()),
                    "output_tokens": len(result[0]["generated_text"].split()),
                    "total_tokens": len(prompt.split()) + len(result[0]["generated_text"].split())
                }
            }
    
    async def _generate_custom_response(
        self, messages: List[Dict], model: str, model_config: Dict,
        tenant_id: str, temperature: Optional[float], max_tokens: Optional[int], timeout: int
    ) -> Dict:
        """Generate response using custom model deployed on tenant cluster"""
        
        # Get tenant cluster endpoint
        cluster_endpoint = await self._get_tenant_cluster_endpoint(tenant_id)
        
        # Prepare request
        prompt = self._messages_to_prompt(messages)
        
        payload = {
            "prompt": prompt,
            "temperature": temperature or model_config["temperature"],
            "max_tokens": max_tokens or model_config["max_tokens"],
            "model": model
        }
        
        # Make request to tenant cluster
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{cluster_endpoint}/api/v1/inference",
                json=payload,
                timeout=timeout
            ) as response:
                if response.status != 200:
                    raise AIServiceError(f"Custom model API error: {response.status}")
                
                result = await response.json()
                
                return {
                    "content": result["response"],
                    "usage": {
                        "input_tokens": result.get("input_tokens", 0),
                        "output_tokens": result.get("output_tokens", 0),
                        "total_tokens": result.get("total_tokens", 0)
                    }
                }
    
    async def _check_tenant_model_access(self, tenant_id: str, model: str, model_config: Dict) -> bool:
        """Check if tenant has access to the specified model"""
        
        # Get tenant configuration
        tenant_config = await self._get_tenant_config(tenant_id)
        
        # Check if model is in tenant's allowed models
        allowed_models = tenant_config.get("allowed_models", [])
        if model not in allowed_models and "*" not in allowed_models:
            return False
        
        # Check provider-specific access
        provider = model_config["provider"]
        allowed_providers = tenant_config.get("allowed_providers", [])
        if provider not in allowed_providers and "*" not in allowed_providers:
            return False
        
        return True
    
    async def _get_tenant_config(self, tenant_id: str) -> Dict:
        """Get tenant configuration from database"""
        # This would query the database for tenant configuration
        # For now, return a default configuration
        return {
            "allowed_models": ["*"],
            "allowed_providers": ["*"],
            "custom_models": [],
            "data_isolation": "strict"
        }
    
    async def _get_tenant_cluster_endpoint(self, tenant_id: str) -> str:
        """Get the endpoint for tenant's dedicated cluster"""
        # This would query the database or service discovery for tenant cluster endpoint
        # For now, return a placeholder
        return f"https://tenant-{tenant_id}-cluster.internal"
    
    def _messages_to_prompt(self, messages: List[Dict]) -> str:
        """Convert messages to a single prompt string"""
        prompt = ""
        for msg in messages:
            role = msg["role"]
            content = msg["content"]
            if role == "user":
                prompt += f"Human: {content}\n\n"
            elif role == "assistant":
                prompt += f"Assistant: {content}\n\n"
        
        prompt += "Assistant:"
        return prompt
    
    def _parse_response(self, response_body: Dict, provider: str) -> Tuple[str, Dict]:
        """Parse response based on provider"""
        if provider == "bedrock":
            if "content" in response_body:
                content = response_body['content'][0]['text']
                usage = response_body.get('usage', {})
            else:
                content = response_body['generation']
                usage = response_body.get('usage', {})
        elif provider == "openai":
            content = response_body["content"]
            usage = response_body.get("usage", {})
        elif provider in ["huggingface", "custom"]:
            content = response_body["content"]
            usage = response_body.get("usage", {})
        else:
            raise AIServiceError(f"Unsupported provider: {provider}")
        
        return content, usage
    
    def _calculate_cost(self, model: str, input_tokens: int, output_tokens: int, model_config: Dict) -> float:
        """Calculate cost based on token usage"""
        input_cost = (input_tokens / 1000) * model_config["cost_per_1k_input"]
        output_cost = (output_tokens / 1000) * model_config["cost_per_1k_output"]
        return round(input_cost + output_cost, 6)
    
    def _update_metrics(self, processing_time: float, cost: float, success: bool, provider: str):
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
        
        # Update provider usage
        if provider not in self.metrics["provider_usage"]:
            self.metrics["provider_usage"][provider] = 0
        self.metrics["provider_usage"][provider] += 1
    
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
        prompt = self._messages_to_prompt(messages)
        
        return {
            "prompt": prompt,
            "max_gen_len": max_tokens,
            "temperature": temperature,
            "top_p": 0.9
        }
    
    def get_metrics(self) -> Dict:
        """Get current performance metrics"""
        return self.metrics.copy()
    
    def get_available_models(self, tenant_id: str) -> List[Dict]:
        """Get list of available models for a specific tenant"""
        tenant_config = asyncio.run(self._get_tenant_config(tenant_id))
        allowed_models = tenant_config.get("allowed_models", [])
        
        available_models = []
        for model_id, config in self.model_configs.items():
            if model_id in allowed_models or "*" in allowed_models:
                available_models.append({
                    "id": model_id,
                    "name": model_id.split(".")[-1].replace("-", " ").title(),
                    "provider": config["provider"],
                    "config": config,
                    "max_concurrent": config["max_concurrent"],
                    "priority": config["priority"]
                })
        
        return available_models
    
    async def train_custom_model(
        self,
        tenant_id: str,
        model_name: str,
        training_data: List[Dict],
        base_model: str = "meta-llama/Llama-2-7b-hf",
        training_config: Optional[Dict] = None
    ) -> Dict:
        """Train a custom model for a specific tenant"""
        
        # Check if tenant has permission to train custom models
        tenant_config = await self._get_tenant_config(tenant_id)
        if not tenant_config.get("allow_custom_training", False):
            raise AIServiceError("Tenant not authorized for custom model training")
        
        # Get tenant cluster endpoint
        cluster_endpoint = await self._get_tenant_cluster_endpoint(tenant_id)
        
        # Prepare training request
        payload = {
            "model_name": model_name,
            "base_model": base_model,
            "training_data": training_data,
            "training_config": training_config or {
                "epochs": 3,
                "learning_rate": 2e-5,
                "batch_size": 4,
                "max_length": 512
            }
        }
        
        # Make request to tenant cluster
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{cluster_endpoint}/api/v1/training",
                json=payload,
                timeout=3600  # 1 hour timeout for training
            ) as response:
                if response.status != 200:
                    raise AIServiceError(f"Custom model training error: {response.status}")
                
                result = await response.json()
                
                # Store model information in tenant configuration
                await self._store_custom_model_info(tenant_id, model_name, result)
                
                return result
    
    async def _store_custom_model_info(self, tenant_id: str, model_name: str, model_info: Dict):
        """Store custom model information in tenant configuration"""
        # This would update the database with custom model information
        # For now, just log it
        logger.info(
            "Custom model trained",
            tenant_id=tenant_id,
            model_name=model_name,
            model_info=model_info
        )
