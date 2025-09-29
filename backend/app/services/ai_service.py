import boto3
import json
import time
import uuid
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
import structlog

from app.core.config import settings
from app.services.rag_service import RAGService
from app.core.exceptions import AIServiceError

logger = structlog.get_logger()

@dataclass
class AIResponse:
    content: str
    model_used: str
    input_tokens: int
    output_tokens: int
    total_tokens: int
    latency_ms: float
    cost_usd: float
    request_id: str

class AIService:
    """Service for interacting with AWS Bedrock AI models"""
    
    def __init__(self):
        self.bedrock_client = boto3.client(
            'bedrock-runtime',
            region_name=settings.BEDROCK_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY
        )
        self.rag_service = RAGService()
        
        # Model configurations
        self.model_configs = {
            "anthropic.claude-3-sonnet-20240229-v1:0": {
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.003,
                "cost_per_1k_output": 0.015
            },
            "anthropic.claude-3-haiku-20240307-v1:0": {
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.00025,
                "cost_per_1k_output": 0.00125
            },
            "meta.llama-2-70b-chat-v1": {
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.00165,
                "cost_per_1k_output": 0.00219
            },
            "meta.llama-2-13b-chat-v1": {
                "max_tokens": 4000,
                "temperature": 0.7,
                "cost_per_1k_input": 0.00075,
                "cost_per_1k_output": 0.001
            }
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
        max_tokens: Optional[int] = None
    ) -> AIResponse:
        """Generate AI response with optional RAG enhancement"""
        
        request_id = str(uuid.uuid4())
        start_time = time.time()
        
        try:
            # Get model configuration
            model_config = self.model_configs.get(model, self.model_configs["anthropic.claude-3-sonnet-20240229-v1:0"])
            
            # Use provided parameters or defaults
            final_temperature = temperature if temperature is not None else model_config["temperature"]
            final_max_tokens = max_tokens if max_tokens is not None else model_config["max_tokens"]
            
            # Enhance prompt with RAG if enabled
            enhanced_prompt = prompt
            if use_rag:
                rag_context = await self.rag_service.get_relevant_context(
                    query=prompt,
                    tenant_id=tenant_id,
                    limit=3
                )
                if rag_context:
                    enhanced_prompt = f"""Context from knowledge base:
{rag_context}

User question: {prompt}

Please answer the user's question using the provided context when relevant."""
            
            # Build conversation context
            messages = []
            if conversation_history:
                for msg in conversation_history[-10:]:  # Limit to last 10 messages
                    messages.append({
                        "role": msg.get("role", "user"),
                        "content": msg.get("content", "")
                    })
            
            # Add current prompt
            messages.append({
                "role": "user",
                "content": enhanced_prompt
            })
            
            # Prepare request body based on model
            if model.startswith("anthropic"):
                request_body = self._prepare_claude_request(
                    messages, final_temperature, final_max_tokens
                )
            elif model.startswith("meta"):
                request_body = self._prepare_llama_request(
                    messages, final_temperature, final_max_tokens
                )
            else:
                raise AIServiceError(f"Unsupported model: {model}")
            
            # Call Bedrock
            response = self.bedrock_client.invoke_model(
                modelId=model,
                body=json.dumps(request_body),
                contentType='application/json'
            )
            
            # Parse response
            response_body = json.loads(response['body'].read())
            
            if model.startswith("anthropic"):
                content = response_body['content'][0]['text']
                usage = response_body.get('usage', {})
            else:
                content = response_body['generation']
                usage = response_body.get('usage', {})
            
            # Calculate metrics
            latency_ms = (time.time() - start_time) * 1000
            input_tokens = usage.get('input_tokens', 0)
            output_tokens = usage.get('output_tokens', 0)
            total_tokens = input_tokens + output_tokens
            
            # Calculate cost
            cost_usd = self._calculate_cost(
                model, input_tokens, output_tokens, model_config
            )
            
            # Store in RAG if this was a useful interaction
            if use_rag and len(prompt) > 50:  # Only store substantial prompts
                await self.rag_service.store_interaction(
                    prompt=prompt,
                    response=content,
                    tenant_id=tenant_id,
                    user_id=user_id
                )
            
            logger.info(
                "AI response generated",
                request_id=request_id,
                model=model,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                latency_ms=latency_ms,
                cost_usd=cost_usd,
                tenant_id=tenant_id
            )
            
            return AIResponse(
                content=content,
                model_used=model,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                total_tokens=total_tokens,
                latency_ms=latency_ms,
                cost_usd=cost_usd,
                request_id=request_id
            )
            
        except Exception as e:
            logger.error(
                "AI service error",
                request_id=request_id,
                error=str(e),
                model=model,
                tenant_id=tenant_id
            )
            raise AIServiceError(f"Failed to generate response: {str(e)}")
    
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
        # Convert messages to prompt format for Llama
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
    
    def _calculate_cost(self, model: str, input_tokens: int, output_tokens: int, model_config: Dict) -> float:
        """Calculate cost based on token usage"""
        input_cost = (input_tokens / 1000) * model_config["cost_per_1k_input"]
        output_cost = (output_tokens / 1000) * model_config["cost_per_1k_output"]
        return round(input_cost + output_cost, 6)
    
    def get_available_models(self) -> List[Dict]:
        """Get list of available models with their configurations"""
        return [
            {
                "id": model_id,
                "name": model_id.split(".")[-1].replace("-", " ").title(),
                "provider": model_id.split(".")[0],
                "config": config
            }
            for model_id, config in self.model_configs.items()
        ]
