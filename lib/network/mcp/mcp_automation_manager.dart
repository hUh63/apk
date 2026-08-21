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

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../mcp/mcp_server.dart';

/// MCP 自动化任务触发器类型
enum AutomationTriggerType {
  onRequest('请求匹配'),      // 当请求匹配条件时触发
  onResponse('响应匹配'),    // 当响应匹配条件时触发
  onInterval('定时触发'),    // 按固定间隔触发
  onProxyStart('代理启动'),  // 代理启动时触发
  onProxyStop('代理停止'),   // 代理停止时触发
  manual('手动触发');        // 手动触发

  final String label;
  const AutomationTriggerType(this.label);
}

/// MCP 自动化任务动作类型
enum AutomationActionType {
  modifyRequest('修改请求'),      // 修改请求头/体
  modifyResponse('修改响应'),    // 修改响应头/体
  blockRequest('拦截请求'),      // 拦截/阻止请求
  replayRequest('重放请求'),     // 重新发送请求
  exportData('导出数据'),        // 导出 HAR/JSON
  runScript('执行脚本'),         // 执行 JavaScript/Dart 脚本
  sendNotification('发送通知'),  // 发送系统通知
  callWebhook('调用 Webhook');   // 调用外部 Webhook

  final String label;
  const AutomationActionType(this.label);
}

/// MCP 自动化任务模型
class MCPAutomationTask {
  final String id;
  final String name;
  final String description;
  final AutomationTriggerType triggerType;
  final List<AutomationActionType> actions;
  final Map<String, dynamic> conditions;  // 触发条件
  final Map<String, dynamic> actionParams; // 动作参数
  final bool enabled;
  final int executionCount;
  final DateTime? lastExecutedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MCPAutomationTask({
    required this.id,
    required this.name,
    this.description = '',
    required this.triggerType,
    required this.actions,
    this.conditions = const {},
    this.actionParams = const {},
    this.enabled = true,
    this.executionCount = 0,
    this.lastExecutedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 检查请求是否匹配条件
  bool matchesRequest(Map<String, dynamic> request) {
    if (triggerType != AutomationTriggerType.onRequest) return false;
    
    // URL 匹配
    if (conditions.containsKey('urlPattern')) {
      final pattern = conditions['urlPattern'] as String;
      final url = request['url'] as String?;
      if (url == null || !url.contains(pattern)) return false;
    }
    
    // 方法匹配
    if (conditions.containsKey('methods')) {
      final methods = conditions['methods'] as List;
      final method = request['method'] as String?;
      if (method == null || !methods.contains(method)) return false;
    }
    
    // Header 匹配
    if (conditions.containsKey('headers')) {
      final headers = conditions['headers'] as Map;
      final reqHeaders = request['headers'] as Map?;
      if (reqHeaders == null) return false;
      for (final entry in headers.entries) {
        if (reqHeaders[entry.key] != entry.value) return false;
      }
    }
    
    return true;
  }

  /// 检查响应是否匹配条件
  bool matchesResponse(Map<String, dynamic> response) {
    if (triggerType != AutomationTriggerType.onResponse) return false;
    
    // 状态码匹配
    if (conditions.containsKey('statusCode')) {
      final statusCode = conditions['statusCode'] as int;
      final respStatus = response['statusCode'] as int?;
      if (respStatus == null || respStatus != statusCode) return false;
    }
    
    // URL 匹配
    if (conditions.containsKey('urlPattern')) {
      final pattern = conditions['urlPattern'] as String;
      final url = response['url'] as String?;
      if (url == null || !url.contains(pattern)) return false;
    }
    
    return true;
  }

  MCPAutomationTask copyWith({
    String? name,
    String? description,
    AutomationTriggerType? triggerType,
    List<AutomationActionType>? actions,
    Map<String, dynamic>? conditions,
    Map<String, dynamic>? actionParams,
    bool? enabled,
    int? executionCount,
    DateTime? lastExecutedAt,
  }) {
    return MCPAutomationTask(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      triggerType: triggerType ?? this.triggerType,
      actions: actions ?? this.actions,
      conditions: conditions ?? this.conditions,
      actionParams: actionParams ?? this.actionParams,
      enabled: enabled ?? this.enabled,
      executionCount: executionCount ?? this.executionCount,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'triggerType': triggerType.name,
      'actions': actions.map((a) => a.name).toList(),
      'conditions': conditions,
      'actionParams': actionParams,
      'enabled': enabled,
      'executionCount': executionCount,
      'lastExecutedAt': lastExecutedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MCPAutomationTask.fromJson(Map<String, dynamic> json) {
    return MCPAutomationTask(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      triggerType: AutomationTriggerType.values.firstWhere(
        (e) => e.name == json['triggerType'],
        orElse: () => AutomationTriggerType.manual,
      ),
      actions: (json['actions'] as List)
          .map((a) => AutomationActionType.values.firstWhere(
                (e) => e.name == a,
                orElse: () => AutomationActionType.runScript,
              ))
          .toList(),
      conditions: Map<String, dynamic>.from(json['conditions'] ?? {}),
      actionParams: Map<String, dynamic>.from(json['actionParams'] ?? {}),
      enabled: json['enabled'] as bool? ?? true,
      executionCount: json['executionCount'] as int? ?? 0,
      lastExecutedAt: json['lastExecutedAt'] != null
          ? DateTime.parse(json['lastExecutedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// MCP 自动化任务管理器
class MCPAutomationManager {
  static final MCPAutomationManager _instance = MCPAutomationManager._internal();
  factory MCPAutomationManager() => _instance;
  MCPAutomationManager._internal();

  static const String _tasksKey = 'mcp_automation_tasks';

  final List<MCPAutomationTask> _tasks = [];
  bool _initialized = false;
  Timer? _intervalTimer;

  /// 初始化 - 从 SharedPreferences 加载任务
  Future<void> init() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    await _loadTasks(prefs);
    _startIntervalTimer();
    _initialized = true;
  }

  /// 从 SharedPreferences 加载任务
  Future<void> _loadTasks(SharedPreferences prefs) async {
    final tasksJson = prefs.getString(_tasksKey);
    if (tasksJson != null && tasksJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(tasksJson);
        _tasks.clear();
        _tasks.addAll(
          decoded.map((e) => MCPAutomationTask.fromJson(e as Map<String, dynamic>)),
        );
      } catch (e) {
        _tasks.clear();
      }
    }
  }

  /// 保存任务到 SharedPreferences
  Future<void> _saveTasks(SharedPreferences prefs) async {
    final tasksJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_tasksKey, tasksJson);
  }

  /// 启动定时任务检查器
  void _startIntervalTimer() {
    _intervalTimer?.cancel();
    _intervalTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkIntervalTasks();
    });
  }

  /// 检查定时任务
  Future<void> _checkIntervalTasks() async {
    for (final task in _tasks.where((t) => 
        t.enabled && t.triggerType == AutomationTriggerType.onInterval)) {
      // TODO: 实现定时任务逻辑
    }
  }

  /// 获取所有任务
  List<MCPAutomationTask> get tasks => List.unmodifiable(_tasks);

  /// 获取启用的任务
  List<MCPAutomationTask> get enabledTasks => 
      _tasks.where((t) => t.enabled).toList();

  /// 添加任务
  Future<MCPAutomationTask> addTask({
    required String name,
    String description = '',
    required AutomationTriggerType triggerType,
    required List<AutomationActionType> actions,
    Map<String, dynamic> conditions = const {},
    Map<String, dynamic> actionParams = const {},
  }) async {
    final task = MCPAutomationTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      triggerType: triggerType,
      actions: actions,
      conditions: conditions,
      actionParams: actionParams,
    );
    
    _tasks.add(task);
    final prefs = await SharedPreferences.getInstance();
    await _saveTasks(prefs);
    
    return task;
  }

  /// 更新任务
  Future<bool> updateTask(String taskId, MCPAutomationTask updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return false;
    
    _tasks[index] = updatedTask;
    final prefs = await SharedPreferences.getInstance();
    await _saveTasks(prefs);
    
    return true;
  }

  /// 删除任务
  Future<bool> deleteTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return false;
    
    _tasks.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await _saveTasks(prefs);
    
    return true;
  }

  /// 切换任务启用状态
  Future<bool> toggleTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return false;
    
    final task = _tasks[index];
    _tasks[index] = task.copyWith(enabled: !task.enabled);
    final prefs = await SharedPreferences.getInstance();
    await _saveTasks(prefs);
    
    return true;
  }

  /// 手动执行任务
  Future<bool> executeTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return false;
    
    final task = _tasks[index];
    await _executeTask(task, {'manual': true});
    return true;
  }

  /// 检查请求匹配并执行自动化任务
  Future<List<String>> onRequest(Map<String, dynamic> request) async {
    final executedActions = <String>[];
    
    for (final task in enabledTasks) {
      if (task.matchesRequest(request)) {
        await _executeTask(task, {'request': request});
        executedActions.add(task.id);
      }
    }
    
    return executedActions;
  }

  /// 检查响应匹配并执行自动化任务
  Future<List<String>> onResponse(Map<String, dynamic> response) async {
    final executedActions = <String>[];
    
    for (final task in enabledTasks) {
      if (task.matchesResponse(response)) {
        await _executeTask(task, {'response': response});
        executedActions.add(task.id);
      }
    }
    
    return executedActions;
  }

  /// 执行任务
  Future<void> _executeTask(
    MCPAutomationTask task,
    Map<String, dynamic> context,
  ) async {
    for (final action in task.actions) {
      switch (action) {
        case AutomationActionType.modifyRequest:
          await _modifyRequest(task, context);
          break;
        case AutomationActionType.modifyResponse:
          await _modifyResponse(task, context);
          break;
        case AutomationActionType.blockRequest:
          await _blockRequest(task, context);
          break;
        case AutomationActionType.replayRequest:
          await _replayRequest(task, context);
          break;
        case AutomationActionType.exportData:
          await _exportData(task, context);
          break;
        case AutomationActionType.runScript:
          await _runScript(task, context);
          break;
        case AutomationActionType.sendNotification:
          await _sendNotification(task, context);
          break;
        case AutomationActionType.callWebhook:
          await _callWebhook(task, context);
          break;
      }
    }
    
    // 更新执行计数
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        executionCount: _tasks[index].executionCount + 1,
        lastExecutedAt: DateTime.now(),
      );
      final prefs = await SharedPreferences.getInstance();
      await _saveTasks(prefs);
    }
  }

  Future<void> _modifyRequest(MCPAutomationTask task, Map<String, dynamic> context) async {
    // TODO: 实现修改请求逻辑
  }

  Future<void> _modifyResponse(MCPAutomationTask task, Map<String, dynamic> context) async {
    // TODO: 实现修改响应逻辑
  }

  Future<void> _blockRequest(MCPAutomationTask task, Map<String, dynamic> context) async {
    // TODO: 实现拦截请求逻辑
  }

  Future<void> _replayRequest(MCPAutomationTask task, Map<String, dynamic> context) async {
    // TODO: 实现重放请求逻辑
  }

  Future<void> _exportData(MCPAutomationTask task, Map<String, dynamic> context) async {
    // TODO: 实现导出数据逻辑
  }

  Future<void> _runScript(MCPAutomationTask task, Map<String, dynamic> context) async {
    // TODO: 实现执行脚本逻辑
  }

  Future<void> _sendNotification(MCPAutomationTask task, Map<String, dynamic> context) async {
    // TODO: 实现发送通知逻辑
  }

  Future<void> _callWebhook(MCPAutomationTask task, Map<String, dynamic> context) async {
    // TODO: 实现调用 Webhook 逻辑
  }

  /// 清空所有任务
  Future<void> clearAllTasks() async {
    _tasks.clear();
    final prefs = await SharedPreferences.getInstance();
    await _saveTasks(prefs);
  }

  /// 导出任务为 JSON
  Future<String> exportTasks() async {
    return jsonEncode(_tasks.map((t) => t.toJson()).toList());
  }

  /// 从 JSON 导入任务
  Future<bool> importTasks(String jsonStr) async {
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      _tasks.clear();
      _tasks.addAll(
        decoded.map((e) => MCPAutomationTask.fromJson(e as Map<String, dynamic>)),
      );
      final prefs = await SharedPreferences.getInstance();
      await _saveTasks(prefs);
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _intervalTimer?.cancel();
  }
}
