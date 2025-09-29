import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

export const api = axios.create({
  baseURL: `${API_BASE_URL}/api/v1`,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// API endpoints
export const authAPI = {
  login: (email: string, password: string) =>
    api.post('/auth/login', { email, password }),
  me: () => api.get('/auth/me'),
};

export const adminAPI = {
  getPromptLogs: (params?: any) => api.get('/admin/prompt-logs', { params }),
  getTenantStats: () => api.get('/admin/tenant-stats'),
  getUsageStats: (days?: number) => api.get('/admin/usage-stats', { params: { days } }),
  getSystemStats: () => api.get('/admin/system-stats'),
  getPromptLog: (id: number) => api.get(`/admin/prompt-logs/${id}`),
};

export const tenantAPI = {
  getTenants: () => api.get('/tenants'),
  createTenant: (data: any) => api.post('/tenants', data),
  getTenant: (id: number) => api.get(`/tenants/${id}`),
  updateTenant: (id: number, data: any) => api.put(`/tenants/${id}`, data),
  deleteTenant: (id: number) => api.delete(`/tenants/${id}`),
};

export const chatAPI = {
  getModels: () => api.get('/chat/models'),
  getConversations: (params?: any) => api.get('/chat/conversations', { params }),
  getConversation: (id: number) => api.get(`/chat/conversations/${id}`),
};

export const ragAPI = {
  uploadDocument: (data: any) => api.post('/rag/documents', data),
  searchDocuments: (query: string, params?: any) => 
    api.get('/rag/search', { params: { query, ...params } }),
  getStats: () => api.get('/rag/stats'),
  deleteDocument: (id: string) => api.delete(`/rag/documents/${id}`),
};
