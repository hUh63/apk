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
import 'package:proxypin/network/mcp/mcp_automation_manager.dart';

/// MCP 自动化任务管理页面 (Feature 5)
class MCPTaskManagerPage extends StatefulWidget {
  const MCPTaskManagerPage({super.key});

  @override
  State<MCPTaskManagerPage> createState() => _MCPTaskManagerPageState();
}

class _MCPTaskManagerPageState extends State<MCPTaskManagerPage> {
  final _manager = MCPAutomationManager();
  List<MCPAutomationTask> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    await _manager.init();
    setState(() {
      _tasks = _manager.tasks;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).mcpAutomationTasks),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showTaskDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyState()
              : _buildTaskList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.automation_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noAutomationTasks,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showTaskDialog(),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).createTask),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: task.enabled ? Colors.blue : Colors.grey,
              child: Icon(
                _getTriggerIcon(task.triggerType),
                color: Colors.white,
              ),
            ),
            title: Text(
              task.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: task.enabled ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(_getTriggerLabel(task.triggerType)),
                Text(
                  '${task.actions.length} 个动作 | 执行 ${task.executionCount} 次',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Switch(
              value: task.enabled,
              onChanged: (value) => _toggleTask(task),
            ),
            onTap: () => _showTaskDetails(task),
            onLongPress: () => _showTaskOptions(task),
          ),
        );
      },
    );
  }

  IconData _getTriggerIcon(AutomationTriggerType type) {
    switch (type) {
      case AutomationTriggerType.onRequest:
        return Icons.http;
      case AutomationTriggerType.onResponse:
        return Icons.swap_horiz;
      case AutomationTriggerType.onInterval:
        return Icons.schedule;
      case AutomationTriggerType.onProxyStart:
      case AutomationTriggerType.onProxyStop:
        return Icons.wifi_tethering;
      case AutomationTriggerType.manual:
        return Icons.touch_app;
    }
  }

  String _getTriggerLabel(AutomationTriggerType type) {
    return type.label;
  }

  Future<void> _showTaskDialog([MCPAutomationTask? task]) async {
    // TODO: 实现添加/编辑任务对话框
  }

  void _showTaskDetails(MCPAutomationTask task) {
    // TODO: 实现任务详情对话框
  }

  void _showTaskOptions(MCPAutomationTask task) {
    // TODO: 实现任务操作菜单
  }

  Future<void> _toggleTask(MCPAutomationTask task) async {
    await _manager.toggleTask(task.id);
    await _loadTasks();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}
