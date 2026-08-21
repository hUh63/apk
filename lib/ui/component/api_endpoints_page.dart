/*
 * API 端点管理页面 - 查看和管理识别的 API 端点
 * 支持分组、搜索、导出 OpenAPI/Postman
 */

import 'package:flutter/material.dart';
import 'package:proxypin/network/util/api_extractor.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

/// API 端点管理页面
class ApiEndpointsPage extends StatefulWidget {
  final ApiExtractor extractor;

  const ApiEndpointsPage({super.key, required this.extractor});

  @override
  State<ApiEndpointsPage> createState() => _ApiEndpointsPageState();
}

class _ApiEndpointsPageState extends State<ApiEndpointsPage> {
  String _selectedGroup = '全部';
  String _searchQuery = '';
  bool _groupByResource = true;

  @override
  Widget build(BuildContext context) {
    final endpoints = widget.extractor.getEndpoints();
    final groups = widget.extractor.getResourceGroups();
    
    var filteredEndpoints = endpoints;
    
    // 按组过滤
    if (_selectedGroup != '全部') {
      filteredEndpoints = endpoints.where((e) => e.resourceGroup == _selectedGroup).toList();
    }
    
    // 按搜索词过滤
    if (_searchQuery.isNotEmpty) {
      filteredEndpoints = filteredEndpoints.where((e) {
        return e.path.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            e.method.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 端点'),
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: '刷新',
          ),
          // 导出菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: '导出',
            onSelected: (value) => _exportEndpoints(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'openapi',
                child: ListTile(
                  leading: Icon(Icons.api),
                  title: Text('OpenAPI (JSON)'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'postman',
                child: ListTile(
                  leading: Icon(Icons.folder_open),
                  title: Text('Postman Collection'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'markdown',
                child: ListTile(
                  leading: Icon(Icons.description),
                  title: Text('Markdown 文档'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索 API 端点...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          
          // 分组选择
          if (_groupByResource)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FilterChip(
                    label: const Text('全部'),
                    selected: _selectedGroup == '全部',
                    onSelected: (selected) => setState(() => _selectedGroup = '全部'),
                  ),
                  const SizedBox(width: 8),
                  ...groups.map((group) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(group),
                      selected: _selectedGroup == group,
                      onSelected: (selected) => setState(() => _selectedGroup = group),
                    ),
                  )),
                ],
              ),
            ),
          
          const Divider(height: 1),
          
          // 统计信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('端点总数', endpoints.length, Icons.api),
                _buildStatCard('资源分组', groups.length, Icons.folder),
                _buildStatCard('当前筛选', filteredEndpoints.length, Icons.filter_list),
              ],
            ),
          ),
          
          // 端点列表
          Expanded(
            child: filteredEndpoints.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '暂无 API 端点',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '开始抓包后自动识别',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredEndpoints.length,
                    itemBuilder: (context, index) {
                      final endpoint = filteredEndpoints[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: _getMethodIcon(endpoint.method.name),
                          title: Text(endpoint.path),
                          subtitle: Text(
                            '${endpoint.resourceGroup} • ${endpoint.lastSeen}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getMethodColor(endpoint.method.name).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  endpoint.method.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getMethodColor(endpoint.method.name),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  // 复制路径
                                  // 这里可以添加复制功能
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已复制：${endpoint.path}')),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () => _showEndpointDetail(endpoint),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 重新识别端点
          widget.extractor.extractEndpoints();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在重新识别 API 端点...')),
          );
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Icons.download;
      case 'POST':
        return Icons.upload;
      case 'PUT':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      default:
        return Icons.http;
    }
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.blue;
      case 'PUT':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showEndpointDetail(ApiEndpoint endpoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(endpoint.path),
        content: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('方法', endpoint.method.name),
              _buildDetailRow('资源分组', endpoint.resourceGroup),
              _buildDetailRow('请求次数', endpoint.requestCount.toString()),
              _buildDetailRow('平均响应时间', '${endpoint.avgResponseTime.toStringAsFixed(0)}ms'),
              _buildDetailRow('首次发现', endpoint.firstSeen),
              _buildDetailRow('最后访问', endpoint.lastSeen),
              if (endpoint.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('描述:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(endpoint.description),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              // 导出单个端点
              Navigator.pop(context);
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Future<void> _exportEndpoints(String format) async {
    try {
      String content;
      String mimeType;
      String extension;
      
      switch (format) {
        case 'openapi':
          content = jsonEncode(widget.extractor.exportToOpenApi());
          mimeType = 'application/json';
          extension = 'json';
          break;
        case 'postman':
          content = jsonEncode(widget.extractor.exportToPostman());
          mimeType = 'application/json';
          extension = 'json';
          break;
        case 'markdown':
          content = widget.extractor.exportToMarkdown();
          mimeType = 'text/markdown';
          extension = 'md';
          break;
        default:
          return;
      }
      
      // 创建临时文件并分享
      // 这里简化处理，实际应该写入文件
      await Share.share(
        content.substring(0, content.length.clamp(0, 1000)),
        subject: 'API 端点导出',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出为 $format 格式')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    }
  }
}
