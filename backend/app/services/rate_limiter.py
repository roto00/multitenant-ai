import redis
import time
from typing import Optional
import structlog

from app.core.database import get_redis
from app.core.exceptions import RateLimitExceededError

logger = structlog.get_logger()

class RateLimiter:
    """Rate limiting service using Redis"""
    
    def __init__(self):
        self.redis_client = get_redis()
    
    async def check_rate_limit(
        self,
        tenant_id: str,
        user_id: int,
        limit_per_minute: Optional[int] = None,
        limit_per_hour: Optional[int] = None
    ) -> bool:
        """Check if user/tenant is within rate limits"""
        
        current_time = int(time.time())
        
        # Check per-minute limit
        if limit_per_minute:
            minute_key = f"rate_limit:{tenant_id}:{user_id}:minute:{current_time // 60}"
            current_minute_count = self.redis_client.get(minute_key)
            
            if current_minute_count and int(current_minute_count) >= limit_per_minute:
                logger.warning(
                    "Rate limit exceeded (per minute)",
                    tenant_id=tenant_id,
                    user_id=user_id,
                    limit=limit_per_minute
                )
                return False
            
            # Increment counter
            pipe = self.redis_client.pipeline()
            pipe.incr(minute_key)
            pipe.expire(minute_key, 60)  # Expire after 1 minute
            pipe.execute()
        
        # Check per-hour limit
        if limit_per_hour:
            hour_key = f"rate_limit:{tenant_id}:{user_id}:hour:{current_time // 3600}"
            current_hour_count = self.redis_client.get(hour_key)
            
            if current_hour_count and int(current_hour_count) >= limit_per_hour:
                logger.warning(
                    "Rate limit exceeded (per hour)",
                    tenant_id=tenant_id,
                    user_id=user_id,
                    limit=limit_per_hour
                )
                return False
            
            # Increment counter
            pipe = self.redis_client.pipeline()
            pipe.incr(hour_key)
            pipe.expire(hour_key, 3600)  # Expire after 1 hour
            pipe.execute()
        
        return True
    
    async def get_rate_limit_status(
        self,
        tenant_id: str,
        user_id: int
    ) -> dict:
        """Get current rate limit status for user/tenant"""
        
        current_time = int(time.time())
        
        # Get per-minute count
        minute_key = f"rate_limit:{tenant_id}:{user_id}:minute:{current_time // 60}"
        minute_count = self.redis_client.get(minute_key) or 0
        
        # Get per-hour count
        hour_key = f"rate_limit:{tenant_id}:{user_id}:hour:{current_time // 3600}"
        hour_count = self.redis_client.get(hour_key) or 0
        
        return {
            "minute_count": int(minute_count),
            "hour_count": int(hour_count),
            "minute_reset": (current_time // 60 + 1) * 60,
            "hour_reset": (current_time // 3600 + 1) * 3600
        }
