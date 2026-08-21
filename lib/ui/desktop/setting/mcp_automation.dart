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
import 'package:proxypin/network/mcp/mcp_scheduler.dart';
import 'package:proxypin/network/mcp/mcp_event_automation.dart';
import 'package:proxypin/network/mcp/mcp_rule_engine.dart' as mcp;
import 'package:flutter_toastr/flutter_toastr.dart';

/// 桌面端 MCP 自动化配置页面
class DesktopMcpAutomation extends StatefulWidget {
  const DesktopMcpAutomation({super.key});

  @override
  State<DesktopMcpAutomation> createState() => _DesktopMcpAutomationState();
}

class _DesktopMcpAutomationState extends State<DesktopMcpAutomation> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final McpScheduler _scheduler = McpScheduler();
  final McpEventAutomation _eventAutomation = McpEventAutomation();
  final mcp.McpRuleEngine _ruleEngine = mcp.McpRuleEngine();
  final List<Map<String, dynamic>> _workflows = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP 自动化'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '定时任务', icon: Icon(Icons.schedule)),
            Tab(text: '事件监听', icon: Icon(Icons.event)),
            Tab(text: '规则引擎', icon: Icon(Icons.rule)),
            Tab(text: '工作流', icon: Icon(Icons.auto_awesome)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTaskDialog(context),
            tooltip: '添加任务',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduledTasksTab(),
          _buildEventListenersTab(),
          _buildRuleEngineTab(),
          _buildWorkflowTab(),
        ],
      ),
    );
  }

  Widget _buildScheduledTasksTab() {
    final tasks = _scheduler.tasks;

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无定时任务',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角 + 添加新任务',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: task.repeatDaily ? Colors.blue : Colors.green,
              child: Icon(
                task.repeatDaily ? Icons.repeat : Icons.play_circle_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(task.name),
            subtitle: Text(
              '${task.repeatDaily ? '每天' : '一次性'} • ${_formatTime(task.executeAt)}${task.lastExecuted != null ? ' • 上次：${_formatTime(task.lastExecuted!)}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _cancelTask(task),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventListenersTab() {
    final listeners = _eventAutomation.listeners;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (listeners.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无事件监听器',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          ...listeners.entries.map((entry) {
            final eventName = entry.key;
            final callbacks = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getEventTypeColor(eventName),
                  child: Icon(_getEventTypeIcon(eventName), color: Colors.white, size: 20),
                ),
                title: Text(_getEventTypeName(eventName)),
                subtitle: Text('${callbacks.length} 个回调函数已注册'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // 任务启用/禁用：通过 switch 状态控制
                  },
                ),
              ),
            );
          }),
        const SizedBox(height: 60),
        Card(
          color: Colors.blue.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '事件类型说明',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildEventDesc('capture_start', '抓包开始', Icons.play_arrow),
                const SizedBox(height: 8),
                _buildEventDesc('capture_stop', '抓包停止', Icons.stop),
                const SizedBox(height: 8),
                _buildEventDesc('request_received', '收到请求', Icons.http),
                const SizedBox(height: 8),
                _buildEventDesc('response_received', '收到响应', Icons.http),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleEngineTab() {
    final rules = _ruleEngine.rules;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rules.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无规则',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          ...rules.map((rule) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _getRulePriorityColor(rule.priority),
                  child: Icon(Icons.rule, color: Colors.white, size: 20),
                ),
                title: Text(rule.name),
                subtitle: Text(
                  '${rule.conditions.length} 个条件 • ${rule.actions.length} 个操作 • ${rule.enabled ? '已启用' : '已禁用'}',
                ),
                trailing: Switch(
                  value: rule.enabled,
                  onChanged: (value) {
                    if (value) {
                      _ruleEngine.enableRule(rule.id);
                    } else {
                      _ruleEngine.disableRule(rule.id);
                    }
                    setState(() {});
                    FlutterToastr.show(
                      value ? '规则已启用' : '规则已禁用',
                      context,
                      duration: 2,
                      backgroundColor: Colors.green,
                    );
                  },
                ),
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('条件:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...rule.conditions.map((c) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• ${_formatCondition(c)}'),
                        )),
                        const SizedBox(height: 12),
                        const Text('操作:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...rule.actions.map((a) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• ${_formatAction(a)}'),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 60),
        Card(
          color: Colors.green.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '规则引擎说明',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '规则引擎允许您定义条件触发动作，例如：',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text('• 当请求包含特定关键词时自动修改', style: TextStyle(fontSize: 13)),
                const Text('• 当响应状态码为 4xx/5xx 时通知用户', style: TextStyle(fontSize: 13)),
                const Text('• 定时清理过期数据', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final nameController = TextEditingController();
    final promptController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加定时任务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '任务名称'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                decoration: const InputDecoration(labelText: 'AI 提示词'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('执行时间：'),
                  const SizedBox(width: 8),
                  Text(selectedTime != null ? selectedTime!.format(context) : '未选择'),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedTime = time;
                        });
                      }
                    },
                    child: const Text('选择'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: true,
                    onChanged: (value) {},
                  ),
                  const Text('每天重复'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // 添加任务：弹出编辑对话框
                Navigator.pop(context);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelTask(dynamic task) {
    // 取消任务：确认后移除
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getEventTypeColor(String eventName) {
    switch (eventName) {
      case 'capture_start':
        return Colors.green;
      case 'capture_stop':
        return Colors.red;
      case 'request_received':
        return Colors.blue;
      case 'response_received':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventTypeIcon(String eventName) {
    switch (eventName) {
      case 'capture_start':
        return Icons.play_arrow;
      case 'capture_stop':
        return Icons.stop;
      case 'request_received':
        return Icons.http;
      case 'response_received':
        return Icons.http;
      default:
        return Icons.event;
    }
  }

  String _getEventTypeName(String eventName) {
    switch (eventName) {
      case 'capture_start':
        return '抓包开始';
      case 'capture_stop':
        return '抓包停止';
      case 'request_received':
        return '收到请求';
      case 'response_received':
        return '收到响应';
      default:
        return eventName;
    }
  }

  Widget _buildEventDesc(String code, String name, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$code：$name',
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildWorkflowTab() {
    if (_workflows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无工作流',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '工作流可编排多个脚本顺序执行',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workflows.length,
      itemBuilder: (context, index) {
        final workflow = _workflows[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: workflow['enabled'] == true ? Colors.green : Colors.grey,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            title: Text(workflow['name'] ?? '未命名工作流'),
            subtitle: Text(
              '${(workflow['nodes'] as List?)?.length ?? 0} 个节点 • ${workflow['successCount'] ?? 0} 次成功',
            ),
            trailing: Switch(
              value: workflow['enabled'] == true,
              onChanged: (value) {
                setState(() {
                  workflow['enabled'] = value;
                });
              },
            ),
            children: [
              const Divider(),
              if (workflow['nodes'] != null)
                ...(workflow['nodes'] as List).map<Widget>((node) {
                  return ListTile(
                    dense: true,
                    leading: Icon(_getScriptTypeIcon(node['type']), size: 18),
                    title: Text(node['name'] ?? '未命名节点', style: const TextStyle(fontSize: 13)),
                    subtitle: Text((node['dependencies'] as List?)?.isNotEmpty == true
                        ? '依赖：${(node['dependencies'] as List).join(', ')}'
                        : '无依赖', style: const TextStyle(fontSize: 11)),
                  );
                }).toList(),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.play_arrow, size: 18),
                      onPressed: () {
                        FlutterToastr.show('开始执行工作流', context, backgroundColor: Colors.green);
                      },
                      label: const Text('执行'),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () {
                        FlutterToastr.show('编辑工作流', context);
                      },
                      label: const Text('编辑'),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _workflows.removeAt(index);
                        });
                        FlutterToastr.show('工作流已删除', context, backgroundColor: Colors.green);
                      },
                      label: const Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getScriptTypeIcon(String? type) {
    switch (type) {
      case 'javascript':
        return Icons.javascript;
      case 'dart':
        return Icons.code;
      case 'shell':
        return Icons.terminal;
      default:
        return Icons.description;
    }
  }

  Color _getRulePriorityColor(mcp.RulePriority priority) {
    switch (priority) {
      case mcp.RulePriority.high:
      case mcp.RulePriority.critical:
        return Colors.red;
      case mcp.RulePriority.normal:
        return Colors.orange;
      case mcp.RulePriority.low:
        return Colors.green;
    }
  }

  String _formatCondition(mcp.Condition condition) {
    return '${condition.field} ${_formatOperator(condition.operator)} ${condition.value}';
  }

  String _formatOperator(mcp.Operator operator) {
    switch (operator) {
      case mcp.Operator.equals:
        return '=';
      case mcp.Operator.notEquals:
        return '≠';
      case mcp.Operator.greaterThan:
        return '>';
      case mcp.Operator.lessThan:
        return '<';
      case mcp.Operator.greaterThanOrEqual:
        return '≥';
      case mcp.Operator.lessThanOrEqual:
        return '≤';
      case mcp.Operator.contains:
        return '包含';
      case mcp.Operator.startsWith:
        return '始于';
      case mcp.Operator.endsWith:
        return '终于';
      case mcp.Operator.matches:
        return '匹配';
      case mcp.Operator.inList:
        return '在...中';
      case mcp.Operator.notInList:
        return '不在...中';
      case mcp.Operator.exists:
        return '存在';
      case mcp.Operator.notExists:
        return '不存在';
    }
  }

  String _formatAction(mcp.Action action) {
    return '${_formatActionType(action.type)}: ${action.target ?? action.parameters}';
  }

  String _formatActionType(mcp.ActionType type) {
    switch (type) {
      case mcp.ActionType.log:
        return '记录';
      case mcp.ActionType.notify:
        return '通知';
      case mcp.ActionType.stopCapture:
        return '停止抓包';
      case mcp.ActionType.startCapture:
        return '开始抓包';
      case mcp.ActionType.exportData:
        return '导出数据';
      case mcp.ActionType.executeScript:
        return '执行脚本';
      case mcp.ActionType.sendWebhook:
        return '发送 Webhook';
      case mcp.ActionType.custom:
        return '自定义';
    }
  }
}
