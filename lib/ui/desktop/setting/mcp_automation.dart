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
import 'package:proxypin/network/mcp/mcp_server.dart';
import 'package:proxypin/network/util/logger.dart';

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
  final McpServer _mcpServer = McpServer();
  
  // Prompts 相关状态
  List<Map<String, dynamic>> _prompts = [];
  bool _isLoadingPrompts = false;
  
  // Roots 相关状态
  final List<Map<String, dynamic>> _roots = [
    {
      'name': 'workspace',
      'uri': 'proxypin://workspace',
      'description': '工作空间目录',
    },
    {
      'name': 'captures',
      'uri': 'proxypin://captures',
      'description': '抓包文件目录',
    },
    {
      'name': 'scripts',
      'uri': 'proxypin://scripts',
      'description': '脚本目录',
    },
  ];
  
  // 工作流列表
  final List<Map<String, dynamic>> _workflows = [
    {
      'name': 'API 安全扫描',
      'description': '自动检测 API 请求中的敏感数据泄露',
      'enabled': true,
      'triggers': ['http_request'],
      'actions': ['analyze', 'notify'],
    },
    {
      'name': '性能监控',
      'description': '监控慢请求并生成报告',
      'enabled': false,
      'triggers': ['response_received'],
      'actions': ['log', 'report'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadPrompts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrompts() async {
    setState(() => _isLoadingPrompts = true);
    try {
      // 从 MCP 服务器获取 Prompts 列表
      final prompts = _mcpServer.getPrompts();
      setState(() {
        _prompts = prompts;
        _isLoadingPrompts = false;
      });
    } catch (e) {
      logger.e('加载 Prompts 失败', error: e);
      setState(() => _isLoadingPrompts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP 自动化'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '定时任务', icon: Icon(Icons.schedule)),
            Tab(text: '事件监听', icon: Icon(Icons.event)),
            Tab(text: '规则引擎', icon: Icon(Icons.rule)),
            Tab(text: '工作流', icon: Icon(Icons.auto_awesome)),
            Tab(text: 'Prompts', icon: Icon(Icons.lightbulb_outline)),
            Tab(text: 'Roots', icon: Icon(Icons.folder)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPrompts();
              setState(() {});
            },
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _handleAddButtonPress(context),
            tooltip: '添加',
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
          _buildPromptsTab(),
          _buildRootsTab(),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: !task.isCancelled,
                  onChanged: (value) {
                    task.isCancelled = !value;
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _cancelTask(task, index),
                ),
              ],
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
                const SizedBox(height: 8),
                Text(
                  '事件监听器由规则引擎和工作流自动注册',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
                    if (!value) {
                      _eventAutomation.removeAllListeners(eventName);
                    }
                    setState(() {});
                  },
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
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
                _buildEventDesc('http_request:*', 'HTTP 请求', Icons.http),
                const SizedBox(height: 8),
                _buildEventDesc('response_received', '收到响应', Icons.http),
                const SizedBox(height: 8),
                _buildEventDesc('network_status:*', '网络状态变化', Icons.wifi),
                const SizedBox(height: 8),
                _buildEventDesc('proxy_status:*', '代理状态变化', Icons.security),
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
                const SizedBox(height: 8),
                Text(
                  '规则可根据条件自动执行操作',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddRuleDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('添加规则'),
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
                    rule.enabled = value;
                    setState(() {});
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _editRule(rule),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('编辑'),
                            ),
                            TextButton.icon(
                              onPressed: () => _deleteRule(rule),
                              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                              label: const Text('删除', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 16),
        Card(
          color: Colors.purple.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.purple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '规则引擎说明',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '支持 14 种条件运算符和 8 种操作类型\n'
                  '• 条件：URL 匹配、方法匹配、状态码、请求头等\n'
                  '• 操作：重定向、修改、阻止、记录、通知等',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._workflows.map((workflow) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: workflow['enabled'] ? Colors.green : Colors.grey,
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                title: Text(workflow['name']),
                subtitle: Text(workflow['description']),
                trailing: Switch(
                  value: workflow['enabled'],
                  onChanged: (value) {
                    workflow['enabled'] = value;
                    setState(() {});
                  },
                ),
                onTap: () => _showWorkflowDetail(workflow),
              ),
            )),
        const SizedBox(height: 16),
        Card(
          color: Colors.orange.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '工作流说明',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '工作流是预定义的自动化脚本，可根据触发条件自动执行一系列操作\n'
                  '• 触发器：HTTP 请求、响应、定时等\n'
                  '• 操作：分析、记录、通知、修改等',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptsTab() {
    if (_isLoadingPrompts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_prompts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无 Prompts 模板',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Prompts 是预定义的 AI 提示模板',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prompts.length,
      itemBuilder: (context, index) {
        final prompt = _prompts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
            ),
            title: Text(prompt['name']),
            subtitle: Text(prompt['description']),
            children: [
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('参数:', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (prompt['arguments'] == null || (prompt['arguments'] as List).isEmpty)
                      const Text('无参数')
                    else
                      ...(prompt['arguments'] as List).map((arg) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(
                                  arg['required'] == true ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: arg['required'] == true ? Colors.amber : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text('${arg['name']}: ${arg['description']}'),
                              ],
                            ),
                          )),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _usePrompt(prompt),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('使用此模板'),
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

  Widget _buildRootsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _roots.length,
      itemBuilder: (context, index) {
        final root = _roots[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.folder, color: Colors.white, size: 20),
            ),
            title: Text(root['name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(root['uri'], style: const TextStyle(fontSize: 12)),
                Text(root['description'], style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openRoot(root),
            ),
            onTap: () => _copyRootUri(root),
          ),
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(minutes: 1));
    bool repeatDaily = false;
    String selectedTaskType = 'mcp_tool';
    String? selectedToolName;
    String? selectedScriptPath;

    // MCP 工具列表
    final mcpTools = _mcpServer.getToolList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加定时任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '任务名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('任务类型:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedTaskType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'mcp_tool', child: Text('MCP 工具调用')),
                    DropdownMenuItem(value: 'script', child: Text('脚本执行')),
                    DropdownMenuItem(value: 'notification', child: Text('系统通知')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedTaskType = value ?? 'mcp_tool';
                      selectedToolName = null;
                      selectedScriptPath = null;
                    });
                  },
                ),
                if (selectedTaskType == 'mcp_tool') ...[
                  const SizedBox(height: 16),
                  const Text('选择 MCP 工具:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedToolName,
                    decoration: const InputDecoration(
                      labelText: '工具名称',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('请选择要调用的工具'),
                    items: mcpTools.map((tool) => DropdownMenuItem(
                      value: tool['name'] as String,
                      child: Text(tool['name'] as String),
                    )).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedToolName = value);
                    },
                  ),
                ],
                if (selectedTaskType == 'script') ...[
                  const SizedBox(height: 16),
                  const Text('脚本路径:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '脚本路径',
                      hintText: '例如：/workspace/scripts/monitor.dart',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => selectedScriptPath = value,
                  ),
                ],
                const SizedBox(height: 16),
                const Text('执行时间:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(_formatDateTime(selectedDate)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: repeatDaily,
                      onChanged: (value) {
                        setDialogState(() => repeatDaily = value ?? false);
                      },
                    ),
                    const Text('每天重复'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入任务名称')),
                  );
                  return;
                }
                if (selectedTaskType == 'mcp_tool' && selectedToolName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请选择 MCP 工具')),
                  );
                  return;
                }
                if (selectedTaskType == 'script' && (selectedScriptPath == null || selectedScriptPath!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入脚本路径')),
                  );
                  return;
                }

                _scheduler.scheduleTask(
                  name: nameController.text,
                  executeAt: selectedDate,
                  action: () {
                    logger.i('执行定时任务：${nameController.text}');
                    // 根据任务类型执行不同动作
                    switch (selectedTaskType) {
                      case 'mcp_tool':
                        logger.i('调用 MCP 工具：$selectedToolName');
                        // _mcpServer.callTool(selectedToolName!, {});
                        break;
                      case 'script':
                        logger.i('执行脚本：$selectedScriptPath');
                        break;
                      case 'notification':
                        logger.i('发送系统通知');
                        break;
                    }
                  },
                  repeatDaily: repeatDaily,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('定时任务已添加'), backgroundColor: Colors.green),
                );
                setState(() {});
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelTask(dynamic task, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务 "${task.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              _scheduler.tasks.removeAt(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('任务已删除'), backgroundColor: Colors.green),
              );
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editRule(dynamic rule) {
    // TODO: 实现编辑规则对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('功能开发中')),
    );
  }

  void _deleteRule(dynamic rule) {
    // TODO: 实现删除规则
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('功能开发中')),
    );
  }

  void _showWorkflowDetail(Map<String, dynamic> workflow) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(workflow['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(workflow['description']),
              const SizedBox(height: 16),
              const Text('触发器:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...workflow['triggers'].map((t) => Text('• $t')),
              const SizedBox(height: 12),
              const Text('操作:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...workflow['actions'].map((a) => Text('• $a')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _usePrompt(Map<String, dynamic> prompt) {
    // TODO: 实现使用 Prompt 模板
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('使用模板：${prompt['name']}')),
    );
  }

  void _openRoot(Map<String, dynamic> root) {
    // TODO: 实现打开 Root 目录
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('打开目录：${root['name']}')),
    );
  }

  void _copyRootUri(Map<String, dynamic> root) {
    // TODO: 复制 URI 到剪贴板
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制：${root['uri']}')),
    );
  }

  /// 根据当前标签页处理添加按钮点击
  void _handleAddButtonPress(BuildContext context) {
    switch (_tabController.index) {
      case 0: // 定时任务
        _showAddTaskDialog(context);
        break;
      case 1: // 事件监听
        _showAddEventListenerDialog(context);
        break;
      case 2: // 规则引擎
        _showAddRuleDialog(context);
        break;
      case 3: // 工作流
        _showAddWorkflowDialog(context);
        break;
      case 4: // Prompts
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prompts 模板由 MCP 服务器提供')),
        );
        break;
      case 5: // Roots
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roots 目录为内置配置')),
        );
        break;
    }
  }

  /// 添加事件监听器对话框
  void _showAddEventListenerDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedEvent = 'http_request:*';
    final callbackNameController = TextEditingController();

    final eventTypes = [
      {'value': 'http_request:*', 'label': 'HTTP 请求'},
      {'value': 'response_received', 'label': '收到响应'},
      {'value': 'capture_start', 'label': '抓包开始'},
      {'value': 'capture_stop', 'label': '抓包停止'},
      {'value': 'network_status:*', 'label': '网络状态变化'},
      {'value': 'proxy_status:*', 'label': '代理状态变化'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加事件监听器'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '监听器名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('监听事件:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedEvent,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: eventTypes.map((e) => DropdownMenuItem(
                  value: e['value'] as String,
                  child: Text(e['label'] as String),
                )).toList(),
                onChanged: (value) {
                  selectedEvent = value ?? selectedEvent;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: callbackNameController,
                decoration: const InputDecoration(
                  labelText: '回调函数名称',
                  hintText: '例如：onRequestReceived',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入监听器名称')),
                );
                return;
              }
              if (callbackNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入回调函数名称')),
                );
                return;
              }

              _eventAutomation.addListener(selectedEvent, (eventData) {
                logger.i('事件 $selectedEvent 触发，监听器：${nameController.text}');
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('事件监听器已添加'), backgroundColor: Colors.green),
              );
              setState(() {});
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 添加规则对话框
  void _showAddRuleDialog(BuildContext context) {
    final nameController = TextEditingController();
    String conditionType = 'url_contains';
    final conditionValueController = TextEditingController();
    String actionType = 'redirect';
    final actionValueController = TextEditingController();

    final conditionTypes = [
      {'value': 'url_contains', 'label': 'URL 包含'},
      {'value': 'url_matches', 'label': 'URL 正则匹配'},
      {'value': 'method_equals', 'label': '请求方法等于'},
      {'value': 'status_code_equals', 'label': '状态码等于'},
      {'value': 'header_contains', 'label': '请求头包含'},
      {'value': 'body_contains', 'label': '请求体包含'},
    ];

    final actionTypes = [
      {'value': 'redirect', 'label': '重定向'},
      {'value': 'modify_header', 'label': '修改请求头'},
      {'value': 'modify_body', 'label': '修改请求体'},
      {'value': 'block', 'label': '阻止请求'},
      {'value': 'log', 'label': '记录日志'},
      {'value': 'notify', 'label': '发送通知'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加自动化规则'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '规则名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('触发条件:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: conditionType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: conditionTypes.map((c) => DropdownMenuItem(
                  value: c['value'] as String,
                  child: Text(c['label'] as String),
                )).toList(),
                onChanged: (value) {
                  conditionType = value ?? conditionType;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: conditionValueController,
                decoration: const InputDecoration(
                  labelText: '条件值',
                  hintText: '例如：api.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('执行操作:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: actionType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: actionTypes.map((a) => DropdownMenuItem(
                  value: a['value'] as String,
                  child: Text(a['label'] as String),
                )).toList(),
                onChanged: (value) {
                  actionType = value ?? actionType;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: actionValueController,
                decoration: const InputDecoration(
                  labelText: '操作值',
                  hintText: '例如：https://new-url.com',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入规则名称')),
                );
                return;
              }
              if (conditionValueController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入条件值')),
                );
                return;
              }

              _ruleEngine.addRule(mcp.Rule(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                conditions: [
                  mcp.Condition(
                    type: mcp.ConditionType.custom,
                    field: 'request.url',
                    operator: mcp.Operator.contains,
                    value: conditionValueController.text,
                  ),
                ],
                actions: [
                  mcp.Action(
                    type: mcp.ActionType.custom,
                    target: actionValueController.text,
                  ),
                ],
                priority: mcp.RulePriority.normal,
                enabled: true,
              ));

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('规则已添加'), backgroundColor: Colors.green),
              );
              setState(() {});
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 添加工作流对话框
  void _showAddWorkflowDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    List<String> selectedTriggers = [];
    List<String> selectedActions = [];

    final triggerOptions = [
      {'value': 'http_request', 'label': 'HTTP 请求'},
      {'value': 'response_received', 'label': '收到响应'},
      {'value': 'capture_start', 'label': '抓包开始'},
      {'value': 'scheduled', 'label': '定时触发'},
    ];

    final actionOptions = [
      {'value': 'analyze', 'label': '分析数据'},
      {'value': 'notify', 'label': '发送通知'},
      {'value': 'log', 'label': '记录日志'},
      {'value': 'report', 'label': '生成报告'},
      {'value': 'modify', 'label': '修改请求'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加工作流'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '工作流名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('触发器:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...triggerOptions.map((t) => CheckboxListTile(
                  title: Text(t['label'] as String),
                  value: selectedTriggers.contains(t['value']),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selectedTriggers.add(t['value'] as String);
                      } else {
                        selectedTriggers.remove(t['value']);
                      }
                    });
                  },
                )),
                const SizedBox(height: 16),
                const Text('操作:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...actionOptions.map((a) => CheckboxListTile(
                  title: Text(a['label'] as String),
                  value: selectedActions.contains(a['value']),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selectedActions.add(a['value'] as String);
                      } else {
                        selectedActions.remove(a['value']);
                      }
                    });
                  },
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入工作流名称')),
                  );
                  return;
                }
                if (selectedTriggers.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请至少选择一个触发器')),
                  );
                  return;
                }
                if (selectedActions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请至少选择一个操作')),
                  );
                  return;
                }

                _workflows.add({
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'enabled': true,
                  'triggers': selectedTriggers,
                  'actions': selectedActions,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('工作流已添加'), backgroundColor: Colors.green),
                );
                setState(() {});
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getEventTypeColor(String eventName) {
    switch (eventName) {
      case 'capture_start':
        return Colors.green;
      case 'capture_stop':
        return Colors.red;
      case 'http_request':
      case 'http_request:*':
        return Colors.blue;
      case 'response_received':
        return Colors.orange;
      case 'network_status':
      case 'network_status:*':
        return Colors.teal;
      case 'proxy_status':
      case 'proxy_status:*':
        return Colors.purple;
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
      case 'http_request':
      case 'http_request:*':
        return Icons.http;
      case 'response_received':
        return Icons.http;
      case 'network_status':
      case 'network_status:*':
        return Icons.wifi;
      case 'proxy_status':
      case 'proxy_status:*':
        return Icons.security;
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
      case 'http_request':
      case 'http_request:*':
        return 'HTTP 请求';
      case 'response_received':
        return '收到响应';
      case 'network_status':
      case 'network_status:*':
        return '网络状态变化';
      case 'proxy_status':
      case 'proxy_status:*':
        return '代理状态变化';
      default:
        return eventName;
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

  String _formatCondition(dynamic condition) {
    return '${condition.field} ${condition.operator} ${condition.value}';
  }

  String _formatAction(dynamic action) {
    return '${action.type}: ${action.description}';
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
}
