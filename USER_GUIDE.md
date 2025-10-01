# Multi-tenant AI Platform - User Guide

## Welcome to the Multi-tenant AI Platform! 🤖

This guide will help you get started with our AI-powered chat platform. Whether you're a business user, developer, or administrator, you'll find everything you need to make the most of our AI capabilities.

## 🌐 Access Your Platform

**Your AI Platform URL**: `http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com`

### Quick Access Links
- **📚 API Documentation**: [http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/docs](http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/docs)
- **💬 Chat Interface**: [http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/](http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/)
- **🏥 Health Check**: [http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/ping](http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/ping)

## 🚀 Getting Started

### Step 1: Get Your API Access

Before you can use the platform, you'll need:
1. **API Token**: Your authentication key
2. **Tenant ID**: Your organization identifier
3. **User Credentials**: Your login information

Contact your administrator to get these credentials.

### Step 2: Test Your Connection

Let's make sure everything is working:

```bash
# Test basic connectivity
curl http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/ping
# Should return: "pong"
```

### Step 3: Explore the API Documentation

Visit the interactive API documentation at `/docs` to see all available endpoints and try them out directly in your browser.

## 💬 Using the Chat API

### Basic Chat Request

Send a message to the AI and get a response:

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello! Can you help me understand machine learning?",
    "use_rag": true
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/
```

### Response Example

```json
{
  "response": "Hello! I'd be happy to help you understand machine learning. Machine learning is a subset of artificial intelligence that enables computers to learn and make decisions from data without being explicitly programmed for every task...",
  "conversation_id": 123,
  "model_used": "gpt-3.5-turbo",
  "tokens_used": 150,
  "latency_ms": 1200,
  "cost_usd": 0.0003,
  "request_id": "req_abc123"
}
```

## 🎛️ Chat Options

### Available AI Models

Get a list of available models:

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "X-Tenant-ID: YOUR_TENANT" \
     http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/models
```

### Customizing Your Chat

You can customize your AI interactions with these parameters:

```json
{
  "message": "Your question here",
  "model": "gpt-3.5-turbo",           // AI model to use
  "temperature": 0.7,                 // Creativity level (0.0-2.0)
  "max_tokens": 1000,                 // Maximum response length
  "use_rag": true,                    // Use knowledge base
  "conversation_id": 123              // Continue existing conversation
}
```

### Parameter Explanations

- **`model`**: Choose from available AI models (GPT-3.5, GPT-4, Claude, etc.)
- **`temperature`**: Controls randomness (0.0 = focused, 2.0 = creative)
- **`max_tokens`**: Limits response length (higher = longer responses)
- **`use_rag`**: Enables retrieval-augmented generation for better context
- **`conversation_id`**: Links messages to create ongoing conversations

## 📚 Managing Conversations

### Get Your Conversation History

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "X-Tenant-ID: YOUR_TENANT" \
     "http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/conversations"
```

### Get a Specific Conversation

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "X-Tenant-ID: YOUR_TENANT" \
     "http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/conversations/123"
```

### Continue a Conversation

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Can you tell me more about that?",
    "conversation_id": 123,
    "use_rag": true
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/
```

## 🔍 Using RAG (Knowledge Base)

RAG (Retrieval-Augmented Generation) allows the AI to use your organization's documents to provide more accurate and relevant responses.

### Upload Documents

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -F "file=@document.pdf" \
  -F "title=Company Handbook" \
  -F "description=Internal policies and procedures" \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/rag/documents
```

### List Your Documents

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "X-Tenant-ID: YOUR_TENANT" \
     http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/rag/documents
```

### Search Documents

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What is our vacation policy?",
    "limit": 5
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/rag/search
```

## 🏢 Tenant Management (Administrators)

### Create a New Tenant

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "new-company",
    "display_name": "New Company Inc",
    "default_model": "gpt-3.5-turbo",
    "rate_limit_per_minute": 60,
    "rate_limit_per_hour": 1000
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/tenants/
```

### List All Tenants

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/tenants/
```

### Update Tenant Settings

```bash
curl -X PUT \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "default_model": "gpt-4",
    "rate_limit_per_minute": 100
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/tenants/123
```

## 📊 Monitoring & Analytics

### Platform Statistics

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/admin/stats
```

### Usage Analytics

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     "http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/admin/usage?start_date=2025-01-01&end_date=2025-01-31"
```

## 🛠️ Integration Examples

### Python Integration

```python
import requests

class AIPlatformClient:
    def __init__(self, base_url, token, tenant_id):
        self.base_url = base_url
        self.headers = {
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": tenant_id,
            "Content-Type": "application/json"
        }
    
    def chat(self, message, **kwargs):
        response = requests.post(
            f"{self.base_url}/api/v1/chat/",
            headers=self.headers,
            json={"message": message, **kwargs}
        )
        return response.json()
    
    def get_conversations(self):
        response = requests.get(
            f"{self.base_url}/api/v1/chat/conversations",
            headers=self.headers
        )
        return response.json()

# Usage
client = AIPlatformClient(
    "http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com",
    "your_token",
    "your_tenant"
)

response = client.chat("What is artificial intelligence?", use_rag=True)
print(response["response"])
```

### JavaScript Integration

```javascript
class AIPlatformClient {
    constructor(baseUrl, token, tenantId) {
        this.baseUrl = baseUrl;
        this.headers = {
            'Authorization': `Bearer ${token}`,
            'X-Tenant-ID': tenantId,
            'Content-Type': 'application/json'
        };
    }
    
    async chat(message, options = {}) {
        const response = await fetch(`${this.baseUrl}/api/v1/chat/`, {
            method: 'POST',
            headers: this.headers,
            body: JSON.stringify({ message, ...options })
        });
        return await response.json();
    }
    
    async getConversations() {
        const response = await fetch(`${this.baseUrl}/api/v1/chat/conversations`, {
            headers: this.headers
        });
        return await response.json();
    }
}

// Usage
const client = new AIPlatformClient(
    'http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com',
    'your_token',
    'your_tenant'
);

client.chat('Explain quantum computing', { use_rag: true })
    .then(response => console.log(response.response));
```

### cURL Examples for Common Tasks

```bash
# 1. Health Check
curl http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/ping

# 2. Get Available Models
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "X-Tenant-ID: YOUR_TENANT" \
     http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/models

# 3. Simple Chat
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, AI!"}' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/

# 4. Advanced Chat with Options
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Write a creative story about a robot",
    "model": "gpt-4",
    "temperature": 1.2,
    "max_tokens": 500,
    "use_rag": false
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/
```

## 🔒 Security Best Practices

### API Token Security
- **Never share your API token** in public repositories or client-side code
- **Rotate tokens regularly** for enhanced security
- **Use environment variables** to store tokens securely
- **Monitor token usage** for any suspicious activity

### Request Security
- **Always use HTTPS** in production (currently HTTP for demo)
- **Validate input data** before sending requests
- **Implement rate limiting** in your applications
- **Log API usage** for audit purposes

### Data Privacy
- **Don't send sensitive data** in chat messages
- **Be aware of data retention** policies
- **Use RAG responsibly** with appropriate documents
- **Review conversation history** regularly

## 🚨 Error Handling

### Common Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 401 | Unauthorized | Check your API token and tenant ID |
| 403 | Forbidden | Verify your permissions |
| 429 | Rate Limited | Wait before making more requests |
| 500 | Server Error | Contact support |

### Error Response Format

```json
{
  "detail": "Error description",
  "error_code": "SPECIFIC_ERROR_CODE",
  "timestamp": "2025-10-01T20:00:00Z"
}
```

### Handling Errors in Code

```python
import requests

try:
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()  # Raises exception for 4xx/5xx
    result = response.json()
except requests.exceptions.HTTPError as e:
    if e.response.status_code == 401:
        print("Authentication failed - check your token")
    elif e.response.status_code == 429:
        print("Rate limited - wait before retrying")
    else:
        print(f"HTTP error: {e}")
except requests.exceptions.RequestException as e:
    print(f"Request failed: {e}")
```

## 📈 Performance Tips

### Optimizing Requests
- **Use appropriate model sizes** for your use case
- **Set reasonable token limits** to control costs
- **Batch similar requests** when possible
- **Cache responses** for repeated queries

### Cost Management
- **Monitor token usage** through the API
- **Use cheaper models** for simple tasks
- **Implement request caching** to reduce API calls
- **Set up usage alerts** to avoid unexpected costs

### Response Time Optimization
- **Use streaming** for long responses (if available)
- **Implement timeout handling** in your code
- **Use connection pooling** for multiple requests
- **Consider async requests** for better performance

## 🆘 Getting Help

### Self-Service Resources
1. **API Documentation**: Visit `/docs` for interactive API explorer
2. **Health Checks**: Use `/ping` and `/health` to verify system status
3. **Error Logs**: Check response details for troubleshooting

### Support Channels
- **Technical Issues**: Contact your system administrator
- **API Questions**: Review the [Developer Guide](DEVELOPER_GUIDE.md)
- **Feature Requests**: Submit through your organization's channels

### Status Page
Monitor platform status at: `http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/health`

## 🎯 Use Cases & Examples

### Customer Support
```bash
# Answer customer questions using company knowledge base
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is your return policy?",
    "use_rag": true
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/
```

### Content Generation
```bash
# Generate marketing content
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Write a product description for our new AI-powered analytics tool",
    "model": "gpt-4",
    "temperature": 0.8,
    "max_tokens": 300
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/
```

### Data Analysis
```bash
# Get insights from data
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Analyze this sales data and provide insights: [data here]",
    "model": "gpt-4",
    "temperature": 0.3
  }' \
  http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/api/v1/chat/
```

## 🔄 Updates & Changes

### Staying Informed
- **API Versioning**: Check the API version in responses
- **Changelog**: Review updates in your organization's communication channels
- **Testing**: Always test changes in a development environment first

### Migration Guide
When the platform is updated:
1. **Review breaking changes** in the changelog
2. **Update your integration code** as needed
3. **Test thoroughly** before deploying to production
4. **Monitor for issues** after deployment

---

## 📞 Quick Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/ping` | GET | Quick health check |
| `/health` | GET | Detailed health status |
| `/docs` | GET | Interactive API documentation |
| `/api/v1/chat/` | POST | Send chat message |
| `/api/v1/chat/conversations` | GET | List conversations |
| `/api/v1/chat/models` | GET | Available AI models |
| `/api/v1/rag/documents` | POST | Upload documents |
| `/api/v1/rag/search` | POST | Search knowledge base |

**Remember**: Always include your `Authorization: Bearer YOUR_TOKEN` and `X-Tenant-ID: YOUR_TENANT` headers in your requests!

---

**Happy AI Chatting! 🤖✨**

*Last Updated: October 1, 2025*
*Platform Version: 1.0.0*
