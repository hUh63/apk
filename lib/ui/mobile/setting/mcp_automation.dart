import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/mcp/mcp_scheduler.dart';
import 'package:proxypin/network/mcp/mcp_event_automation.dart';
import 'package:proxypin/network/mcp/mcp_rule_engine.dart';
import 'package:proxypin/network/util/logger.dart';

/// MCP 自动化配置页面 - 定时任务、事件规则管理
class McpAutomationPage extends StatefulWidget {
  const McpAutomationPage({super.key});

  @override
  State<StatefulWidget> createState() => _McpAutomationPageState();
}

class _McpAutomationPageState extends State<McpAutomationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final McpScheduler _scheduler = McpScheduler();
  final McpEventAutomation _eventAutomation = McpEventAutomation();
  final McpRuleEngine _ruleEngine = McpRuleEngine();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MCP 自动化',
          style: TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '定时任务', icon: Icon(Icons.schedule)),
            Tab(text: '事件监听', icon: Icon(Icons.event)),
            Tab(text: '规则引擎', icon: Icon(Icons.rule)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduledTasksTab(),
          _buildEventListenersTab(),
          _buildRuleEngineTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add),
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
              '点击右下角 + 添加新任务',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: task.repeatDaily ? Colors.blue : Colors.green,
              child: Icon(
                task.repeatDaily ? Icons.repeat : Icons.play_once,
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
      padding: const EdgeInsets.all(12),
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
          ...listeners.map((listener) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getEventTypeColor(listener.eventType),
                    child: Icon(_getEventTypeIcon(listener.eventType),
                        color: Colors.white, size: 20),
                  ),
                  title: Text(_getEventTypeName(listener.eventType)),
                  subtitle: Text('回调函数已注册'),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      // TODO: 实现启用/禁用
                    },
                  ),
                ),
              )),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '• HTTP 请求事件：监听新的 HTTP 请求\n'
                  '• 网络状态事件：监听网络连接/断开\n'
                  '• 代理状态事件：监听代理启动/停止',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
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
      padding: const EdgeInsets.all(12),
      children: [
        if (rules.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无自动化规则',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  '规则可根据条件自动执行操作',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          ...rules.map((rule) => Card(
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
                    onChanged: (value) => _toggleRule(rule),
                  ),
                  children: [
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('条件:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...rule.conditions.map((c) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• ${_formatCondition(c)}'),
                              )),
                          const SizedBox(height: 12),
                          const Text('操作:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...rule.actions.map((a) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• ${_formatAction(a)}'),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 60),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '支持 14 种条件运算符和 8 种操作类型\n'
                  '• 条件：URL 匹配、方法匹配、状态码、请求头等\n'
                  '• 操作：重定向、修改、阻止、记录、通知等',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final nameController = TextEditingController();
    DateTime selectedTime = DateTime.now().add(const Duration(minutes: 1));
    bool repeatDaily = false;

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
                const Text('执行时间:'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedTime),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedTime = DateTime(
                          selectedTime.year,
                          selectedTime.month,
                          selectedTime.day,
                          picked.hour,
                          picked.minute,
                        );
                        if (selectedTime.isBefore(DateTime.now())) {
                          selectedTime = selectedTime.add(const Duration(days: 1));
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
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
                  FlutterToastr.show('请输入任务名称', context,
                      duration: 2, backgroundColor: Colors.red);
                  return;
                }

                _scheduler.scheduleTask(
                  name: nameController.text,
                  executeAt: selectedTime,
                  action: () {
                    logger.i('执行定时任务：${nameController.text}');
                  },
                  repeatDaily: repeatDaily,
                );

                Navigator.pop(context);
                FlutterToastr.show('定时任务已添加', context,
                    duration: 2, backgroundColor: Colors.green);
                setState(() {});
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelTask(dynamic task) {
    task.isCancelled = true;
    _scheduler.cancelAll();
    setState(() {});
    FlutterToastr.show('任务已取消', context,
        duration: 2, backgroundColor: Colors.green);
  }

  void _toggleRule(dynamic rule) {
    rule.enabled = !rule.enabled;
    setState(() {});
    FlutterToastr.show(
        rule.enabled ? '规则已启用' : '规则已禁用', context,
        duration: 2, backgroundColor: Colors.green);
  }

  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'http_request':
        return Colors.blue;
      case 'network_status':
        return Colors.green;
      case 'proxy_status':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventTypeIcon(String eventType) {
    switch (eventType) {
      case 'http_request':
        return Icons.http;
      case 'network_status':
        return Icons.wifi;
      case 'proxy_status':
        return Icons.security;
      default:
        return Icons.event;
    }
  }

  String _getEventTypeName(String eventType) {
    switch (eventType) {
      case 'http_request':
        return 'HTTP 请求事件';
      case 'network_status':
        return '网络状态事件';
      case 'proxy_status':
        return '代理状态事件';
      default:
        return eventType;
    }
  }

  Color _getRulePriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatCondition(dynamic condition) {
    return '${condition.field} ${condition.operator} ${condition.value}';
  }

  String _formatAction(dynamic action) {
    return '${action.type}: ${action.params}';
  }
}
