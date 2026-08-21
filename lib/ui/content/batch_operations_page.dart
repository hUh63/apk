/*
 * Copyright 2023 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/batch/batch_operations.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/ui/component/app_dialog.dart';

/// 请求批量操作管理页面 (Feature 6)
class BatchOperationsPage extends StatefulWidget {
  final List<HttpRequest> requests;
  final Function(List<String>)? onSelectionChanged;

  const BatchOperationsPage({
    super.key,
    required this.requests,
    this.onSelectionChanged,
  });

  @override
  State<BatchOperationsPage> createState() => _BatchOperationsPageState();
}

class _BatchOperationsPageState extends State<BatchOperationsPage> {
  final BatchOperationsManager _batchManager = BatchOperationsManager();
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _selectAll = _selectedIds.length == widget.requests.length;
      widget.onSelectionChanged?.call(_selectedIds.toList());
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(widget.requests.map((r) => r.id));
      }
      _selectAll = !_selectAll;
      widget.onSelectionChanged?.call(_selectedIds.toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = _batchManager.getStatistics(
      widget.requests,
      selectedIds: _selectedIds.isEmpty ? null : _selectedIds.toList(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('批量操作 (${_selectedIds.length})'),
        actions: [
          IconButton(
            icon: Icon(_selectAll ? Icons.check_box : Icons.check_box_outline_blank),
            tooltip: _selectAll ? '取消全选' : '全选',
            onPressed: _toggleSelectAll,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新统计',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计信息卡片
          _buildStatsCard(stats),
          
          // 操作按钮
          _buildActionButtons(),
          
          // 请求列表
          Expanded(
            child: ListView.builder(
              itemCount: widget.requests.length,
              itemBuilder: (context, index) {
                final request = widget.requests[index];
                final isSelected = _selectedIds.contains(request.id);
                return _buildRequestTile(request, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BatchStatistics stats) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('已选', '${stats.selectedRequests}/${stats.totalRequests}'),
                _buildStatItem('总大小', _formatSize(stats.totalSize)),
                _buildStatItem('GET', '${stats.methodCounts['GET'] ?? 0}'),
                _buildStatItem('POST', '${stats.methodCounts['POST'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      padding: const EdgeInsets.all(8),
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('批量删除'),
          onPressed: _selectedIds.isEmpty ? null : () => _showDeleteConfirm(),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_download),
          label: const Text('导出 HAR'),
          onPressed: _selectedIds.isEmpty ? null : () => _exportHar(),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.data_usage),
          label: const Text('导出 JSON'),
          onPressed: _selectedIds.isEmpty ? null : () => _exportJson(),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text('修改请求头'),
          onPressed: _selectedIds.isEmpty ? null : () => _modifyHeaders(),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('批量重放'),
          onPressed: _selectedIds.isEmpty ? null : () => _batchReplay(),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.clear_all),
          label: const Text('清除请求体'),
          onPressed: _selectedIds.isEmpty ? null : () => _clearBodies(),
        ),
      ],
    );
  }

  Widget _buildRequestTile(HttpRequest request, bool isSelected) {
    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (_) => _toggleSelection(request.id),
      ),
      title: Text(
        request.requestUrl ?? 'Unknown URL',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${request.method ?? 'GET'} • ${request.responseStatusCode ?? '-'} • ${_formatSize(request.contentLength ?? 0)}',
      ),
      trailing: Text(
        _formatTime(request.time),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.withOpacity(0.1),
      onTap: () => _toggleSelection(request.id),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '-';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 操作对话框
  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 个请求吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRequests();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequests() async {
    final selectedRequests = widget.requests
        .where((r) => _selectedIds.contains(r.id))
        .toList();

    final result = await _batchManager.batchDelete(selectedRequests);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除完成：成功 ${result.success}/${result.total}'),
          backgroundColor: result.failed == 0 ? Colors.green : Colors.orange,
        ),
      );
      setState(() {
        _selectedIds.clear();
        _selectAll = false;
      });
    }
  }

  Future<void> _exportHar() async {
    // TODO: 实现文件选择对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HAR 导出功能开发中...')),
    );
  }

  Future<void> _exportJson() async {
    // TODO: 实现文件选择对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON 导出功能开发中...')),
    );
  }

  Future<void> _modifyHeaders() async {
    // TODO: 实现修改请求头对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('修改请求头功能开发中...')),
    );
  }

  Future<void> _batchReplay() async {
    final selectedRequests = widget.requests
        .where((r) => _selectedIds.contains(r.id))
        .toList();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开始批量重放...')),
    );

    final result = await _batchManager.batchReplay(selectedRequests);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('重放完成：成功 ${result.success}/${result.total}'),
          backgroundColor: result.failed == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _clearBodies() async {
    final selectedRequests = widget.requests
        .where((r) => _selectedIds.contains(r.id))
        .toList();

    final result = await _batchManager.batchClearBodies(selectedRequests);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清除完成：成功 ${result.success}/${result.total}'),
          backgroundColor: result.failed == 0 ? Colors.green : Colors.orange,
        ),
      );
      setState(() {});
    }
  }
}
