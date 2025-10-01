# Multi-tenant AI Platform - Developer Guide

## Overview

The Multi-tenant AI Platform is a scalable, cloud-native application built with FastAPI, designed to provide AI chat capabilities with RAG (Retrieval-Augmented Generation) support for multiple tenants. The platform is deployed on AWS using ECS, RDS, ElastiCache, and Application Load Balancer.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client Apps   │    │   Web Browser   │    │   Mobile Apps   │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │   Application Load        │
                    │   Balancer (ALB)          │
                    └─────────────┬─────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │   ECS Fargate Service     │
                    │   (FastAPI Application)   │
                    └─────────────┬─────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          │                      │                      │
┌─────────▼───────┐    ┌─────────▼───────┐    ┌─────────▼───────┐
│   PostgreSQL    │    │   ElastiCache   │    │   S3 Bucket     │
│   (RDS)         │    │   (Redis)       │    │   (Storage)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Technology Stack

### Backend
- **FastAPI**: Modern, fast web framework for building APIs
- **SQLAlchemy**: SQL toolkit and ORM
- **PostgreSQL**: Primary database (AWS RDS)
- **Redis**: Caching and session storage (AWS ElastiCache)
- **Pydantic**: Data validation using Python type annotations
- **Structlog**: Structured logging
- **Uvicorn**: ASGI server

### AI/ML
- **OpenAI API**: GPT models integration
- **Anthropic API**: Claude models integration
- **Sentence Transformers**: Text embeddings for RAG
- **ChromaDB**: Vector database for document storage
- **LangChain**: AI application framework

### Infrastructure
- **AWS ECS Fargate**: Container orchestration
- **AWS RDS**: Managed PostgreSQL database
- **AWS ElastiCache**: Managed Redis cache
- **AWS ALB**: Application load balancer
- **AWS ECR**: Container registry
- **AWS CodeBuild**: CI/CD pipeline
- **Terraform**: Infrastructure as Code

## Project Structure

```
multitenant-ai/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── endpoints/
│   │   │       │   ├── chat.py          # Chat endpoints
│   │   │       │   ├── admin.py         # Admin endpoints
│   │   │       │   ├── tenants.py       # Tenant management
│   │   │       │   └── rag.py           # RAG endpoints
│   │   │       └── api.py               # API router
│   │   ├── core/
│   │   │   ├── auth.py                  # Authentication
│   │   │   ├── config.py                # Configuration
│   │   │   ├── database.py              # Database setup
│   │   │   ├── exceptions.py            # Custom exceptions
│   │   │   └── middleware.py            # Custom middleware
│   │   ├── models/
│   │   │   ├── user.py                  # User model
│   │   │   ├── tenant.py                # Tenant model
│   │   │   ├── conversation.py          # Conversation model
│   │   │   └── prompt_log.py            # Prompt logging model
│   │   ├── schemas/
│   │   │   ├── chat.py                  # Chat schemas
│   │   │   ├── admin.py                 # Admin schemas
│   │   │   ├── tenant.py                # Tenant schemas
│   │   │   └── rag.py                   # RAG schemas
│   │   ├── services/
│   │   │   ├── ai_service.py            # AI service integration
│   │   │   ├── rag_service.py           # RAG functionality
│   │   │   └── rate_limiter.py          # Rate limiting
│   │   └── main.py                      # FastAPI application
│   ├── tests/
│   │   └── test_main.py                 # Basic tests
│   ├── requirements.txt                 # Python dependencies
│   └── Dockerfile                       # Container configuration
├── frontend/                            # React frontend (future)
├── terraform/                           # Infrastructure code
├── scripts/                             # Deployment scripts
└── docs/                                # Documentation
```

## API Endpoints

### Base URL
```
http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com
```

### Health & Status
- `GET /` - Platform information
- `GET /health` - Detailed health check
- `GET /healthz` - Simple health check
- `GET /ping` - Ultra-simple ping
- `GET /docs` - Interactive API documentation

### Chat API
- `POST /api/v1/chat/` - Send message and get AI response
- `GET /api/v1/chat/conversations` - Get user conversations
- `GET /api/v1/chat/conversations/{id}` - Get specific conversation
- `GET /api/v1/chat/models` - Get available AI models

### Tenant Management
- `GET /api/v1/tenants/` - List tenants
- `POST /api/v1/tenants/` - Create tenant
- `GET /api/v1/tenants/{id}` - Get tenant details
- `PUT /api/v1/tenants/{id}` - Update tenant
- `DELETE /api/v1/tenants/{id}` - Delete tenant

### RAG (Retrieval-Augmented Generation)
- `POST /api/v1/rag/documents` - Upload documents
- `GET /api/v1/rag/documents` - List documents
- `DELETE /api/v1/rag/documents/{id}` - Delete document
- `POST /api/v1/rag/search` - Search documents

### Admin
- `GET /api/v1/admin/stats` - Platform statistics
- `GET /api/v1/admin/users` - User management
- `GET /api/v1/admin/usage` - Usage analytics

## Authentication

The platform uses JWT-based authentication with tenant isolation. Each request must include:

1. **Authorization Header**: `Bearer <jwt_token>`
2. **Tenant Header**: `X-Tenant-ID: <tenant_name>`

### Getting an API Token

```bash
# Example: Get token for tenant "demo"
curl -X POST "http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: demo" \
  -d '{
    "username": "your_username",
    "password": "your_password"
  }'
```

## Usage Examples

### 1. Basic Chat Request

```python
import requests

# Set up headers
headers = {
    "Authorization": "Bearer your_jwt_token",
    "X-Tenant-ID": "demo",
    "Content-Type": "application/json"
}

# Send a chat message
response = requests.post(
    "http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/",
    headers=headers,
    json={
        "message": "What is artificial intelligence?",
        "model": "gpt-3.5-turbo",
        "temperature": 0.7,
        "max_tokens": 1000,
        "use_rag": True
    }
)

print(response.json())
```

### 2. JavaScript/Node.js Example

```javascript
const axios = require('axios');

const apiClient = axios.create({
  baseURL: 'http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com',
  headers: {
    'Authorization': 'Bearer your_jwt_token',
    'X-Tenant-ID': 'demo',
    'Content-Type': 'application/json'
  }
});

// Send chat message
async function sendMessage(message) {
  try {
    const response = await apiClient.post('/api/v1/chat/', {
      message: message,
      model: 'gpt-3.5-turbo',
      temperature: 0.7,
      use_rag: true
    });
    
    console.log('AI Response:', response.data.response);
    return response.data;
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
}

// Usage
sendMessage("Explain quantum computing in simple terms");
```

### 3. cURL Examples

```bash
# Health check
curl http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/ping

# Get available models
curl -H "Authorization: Bearer your_token" \
     -H "X-Tenant-ID: demo" \
     http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/models

# Send chat message
curl -X POST \
  -H "Authorization: Bearer your_token" \
  -H "X-Tenant-ID: demo" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, how are you?", "use_rag": true}' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/
```

## Data Models

### Chat Request Schema
```json
{
  "message": "string",
  "model": "string (optional)",
  "temperature": "number (0.0-2.0, optional)",
  "max_tokens": "integer (optional)",
  "use_rag": "boolean (optional)",
  "conversation_id": "integer (optional)",
  "conversation_history": "array (optional)"
}
```

### Chat Response Schema
```json
{
  "response": "string",
  "conversation_id": "integer",
  "model_used": "string",
  "tokens_used": "integer",
  "latency_ms": "integer",
  "cost_usd": "number",
  "request_id": "string"
}
```

## Configuration

### Environment Variables

The application uses the following environment variables:

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:port/dbname

# Redis
REDIS_URL=rediss://host:port

# AI Services
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key

# Application
ALLOWED_HOSTS=["*"]
DEBUG=false
LOG_LEVEL=info
```

### Tenant Configuration

Each tenant can be configured with:

- **Default AI Model**: Primary model to use
- **Rate Limits**: Requests per minute/hour
- **Allowed Models**: List of permitted AI models
- **RAG Settings**: Document storage and retrieval config
- **Custom Prompts**: Tenant-specific system prompts

## Development Setup

### Prerequisites
- Python 3.11+
- Docker
- AWS CLI configured
- Terraform

### Local Development

1. **Clone the repository**
```bash
git clone https://github.com/roto00/multitenant-ai.git
cd multitenant-ai
```

2. **Set up Python environment**
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

3. **Set up environment variables**
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. **Run the application**
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

5. **Access the API**
- API: http://localhost:8000
- Docs: http://localhost:8000/docs

### Running Tests

```bash
cd backend
pytest tests/ -v
```

### Docker Development

```bash
# Build the image
docker build -t multitenant-ai-backend .

# Run the container
docker run -p 8000:8000 \
  -e DATABASE_URL="your_db_url" \
  -e REDIS_URL="your_redis_url" \
  multitenant-ai-backend
```

## Deployment

### AWS Deployment

The platform is deployed using Terraform and AWS CodeBuild. See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed deployment instructions.

### Key AWS Resources

- **ECS Cluster**: `multitenant-ai-minimal-cluster`
- **ECS Service**: `multitenant-ai-minimal-service`
- **RDS Instance**: `multitenant-ai-minimal-db`
- **ElastiCache**: `multitenant-ai-minimal-redis`
- **ALB**: `mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com`

## Monitoring & Logging

### CloudWatch Logs
- **ECS Logs**: `/ecs/multitenant-ai-minimal`
- **CodeBuild Logs**: `/aws/codebuild/multitenant-ai-minimal-backend-build`

### Health Monitoring
- Application health checks via `/health` endpoint
- ALB health checks via `/ping` endpoint
- Database and Redis connection monitoring

### Metrics
- Request latency and throughput
- Token usage and costs
- Error rates and types
- Tenant usage statistics

## Security

### Authentication & Authorization
- JWT-based authentication
- Tenant isolation
- Role-based access control
- API key management

### Data Protection
- Encryption in transit (HTTPS)
- Encryption at rest (RDS, ElastiCache)
- Secure environment variable handling
- Input validation and sanitization

### Network Security
- VPC isolation
- Security groups with least privilege
- ALB with SSL termination
- Private subnets for databases

## Troubleshooting

### Common Issues

1. **Health Check Failures**
   - Check security group rules (port 8000)
   - Verify application startup logs
   - Check database/Redis connectivity

2. **Authentication Errors**
   - Verify JWT token validity
   - Check tenant ID header
   - Confirm user permissions

3. **Rate Limiting**
   - Check tenant rate limits
   - Monitor usage patterns
   - Adjust limits if needed

4. **AI Service Errors**
   - Verify API keys
   - Check model availability
   - Monitor token usage

### Debug Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster multitenant-ai-minimal-cluster --services multitenant-ai-minimal-service

# View application logs
aws logs get-log-events --log-group-name /ecs/multitenant-ai-minimal --log-stream-name <stream-name>

# Check target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

### Code Style
- Follow PEP 8 for Python
- Use type hints
- Write comprehensive docstrings
- Include unit tests

## Support

For technical support or questions:
- Check the [User Guide](USER_GUIDE.md)
- Review the [Deployment Guide](DEPLOYMENT_GUIDE.md)
- Open an issue on GitHub
- Contact the development team

---

**Last Updated**: October 1, 2025
**Version**: 1.0.0
