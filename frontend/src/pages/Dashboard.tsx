import React from 'react';
import { useQuery } from 'react-query';
import { adminAPI } from '../services/api';
import {
  UsersIcon,
  DocumentTextIcon,
  ChatBubbleLeftRightIcon,
  CurrencyDollarIcon,
} from '@heroicons/react/24/outline';

const Dashboard: React.FC = () => {
  const { data: systemStats, isLoading: systemStatsLoading } = useQuery(
    'systemStats',
    adminAPI.getSystemStats
  );

  const { data: usageStats, isLoading: usageStatsLoading } = useQuery(
    'usageStats',
    () => adminAPI.getUsageStats(7) // Last 7 days
  );

  const { data: tenantStats, isLoading: tenantStatsLoading } = useQuery(
    'tenantStats',
    adminAPI.getTenantStats
  );

  if (systemStatsLoading || usageStatsLoading || tenantStatsLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="loading-spinner"></div>
      </div>
    );
  }

  const stats = [
    {
      name: 'Total Tenants',
      value: systemStats?.data.total_tenants || 0,
      icon: UsersIcon,
      color: 'text-blue-600',
      bgColor: 'bg-blue-100',
    },
    {
      name: 'Active Tenants',
      value: systemStats?.data.active_tenants || 0,
      icon: UsersIcon,
      color: 'text-green-600',
      bgColor: 'bg-green-100',
    },
    {
      name: 'Total Users',
      value: systemStats?.data.total_users || 0,
      icon: UsersIcon,
      color: 'text-purple-600',
      bgColor: 'bg-purple-100',
    },
    {
      name: 'Total Conversations',
      value: systemStats?.data.total_conversations || 0,
      icon: ChatBubbleLeftRightIcon,
      color: 'text-indigo-600',
      bgColor: 'bg-indigo-100',
    },
    {
      name: 'Total Prompts',
      value: systemStats?.data.total_prompts || 0,
      icon: DocumentTextIcon,
      color: 'text-yellow-600',
      bgColor: 'bg-yellow-100',
    },
    {
      name: 'Total Cost (USD)',
      value: `$${(usageStats?.data.total_cost || 0).toFixed(2)}`,
      icon: CurrencyDollarIcon,
      color: 'text-red-600',
      bgColor: 'bg-red-100',
    },
  ];

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="mt-1 text-sm text-gray-500">
          Overview of your multi-tenant AI platform
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {stats.map((stat) => (
          <div key={stat.name} className="card">
            <div className="flex items-center">
              <div className={`flex-shrink-0 p-3 rounded-md ${stat.bgColor}`}>
                <stat.icon className={`h-6 w-6 ${stat.color}`} />
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    {stat.name}
                  </dt>
                  <dd className="text-lg font-medium text-gray-900">
                    {stat.value}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Recent Activity */}
      <div className="mt-8 grid grid-cols-1 gap-5 lg:grid-cols-2">
        {/* Recent Prompts */}
        <div className="card">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Recent Activity (24h)
          </h3>
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-sm text-gray-500">Prompts</span>
              <span className="text-sm font-medium text-gray-900">
                {systemStats?.data.recent_prompts_24h || 0}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-gray-500">Conversations</span>
              <span className="text-sm font-medium text-gray-900">
                {systemStats?.data.recent_conversations_24h || 0}
              </span>
            </div>
          </div>
        </div>

        {/* Model Usage */}
        <div className="card">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Model Usage (7 days)
          </h3>
          <div className="space-y-3">
            {usageStats?.data.model_usage?.slice(0, 5).map((model: any) => (
              <div key={model.model} className="flex justify-between">
                <span className="text-sm text-gray-500 truncate">
                  {model.model.split('.').pop()}
                </span>
                <span className="text-sm font-medium text-gray-900">
                  {model.count} prompts
                </span>
              </div>
            )) || (
              <p className="text-sm text-gray-500">No data available</p>
            )}
          </div>
        </div>
      </div>

      {/* Top Tenants */}
      <div className="mt-8">
        <div className="card">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Top Tenants by Usage
          </h3>
          <div className="overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="table-header">Tenant</th>
                  <th className="table-header">Users</th>
                  <th className="table-header">Prompts</th>
                  <th className="table-header">Cost</th>
                  <th className="table-header">Status</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {tenantStats?.data?.slice(0, 10).map((tenant: any) => (
                  <tr key={tenant.tenant_id}>
                    <td className="table-cell">
                      <div>
                        <div className="text-sm font-medium text-gray-900">
                          {tenant.display_name}
                        </div>
                        <div className="text-sm text-gray-500">
                          {tenant.tenant_name}
                        </div>
                      </div>
                    </td>
                    <td className="table-cell">{tenant.user_count}</td>
                    <td className="table-cell">{tenant.prompt_count}</td>
                    <td className="table-cell">${tenant.total_cost.toFixed(2)}</td>
                    <td className="table-cell">
                      <span
                        className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                          tenant.is_active
                            ? 'bg-green-100 text-green-800'
                            : 'bg-red-100 text-red-800'
                        }`}
                      >
                        {tenant.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                  </tr>
                )) || (
                  <tr>
                    <td colSpan={5} className="table-cell text-center text-gray-500">
                      No tenant data available
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
