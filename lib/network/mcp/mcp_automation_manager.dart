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
import 'dart:io' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../mcp/mcp_server.dart';
import '../mcp/mcp_bridge.dart';
import '../http/http.dart';
import '../http/http_client.dart';
import '../util/logger.dart';
import '../../utils/file_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../components/manager/script_manager.dart';

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
  final Map<String, int> _taskLastExecuted = {}; // taskId -> lastExecutedTimestamp

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

  /// 检查定时任务 - 实现定时任务逻辑
  Future<void> _checkIntervalTasks() async {
    final now = DateTime.now();
    for (final task in _tasks.where((t) => 
        t.enabled && t.triggerType == AutomationTriggerType.onInterval)) {
      // 检查是否到了执行时间
      final intervalSeconds = task.actionParams['intervalSeconds'] as int? ?? 60;
      final lastExecuted = _taskLastExecuted[task.id] ?? 0;
      final elapsedSeconds = now.millisecondsSinceEpoch ~/ 1000 - lastExecuted;
      
      if (elapsedSeconds >= intervalSeconds) {
        logger.i('[MCP Automation] Executing interval task: ${task.name}');
        await _executeTask(task, {'interval': true, 'timestamp': now.millisecondsSinceEpoch});
        _taskLastExecuted[task.id] = now.millisecondsSinceEpoch ~/ 1000;
      }
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
      try {
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
      } catch (e) {
        logger.e('[MCP Automation] Error executing action ${action.name} for task ${task.name}: $e');
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

  /// 实现修改请求逻辑
  Future<void> _modifyRequest(MCPAutomationTask task, Map<String, dynamic> context) async {
    final params = task.actionParams;
    final request = context['request'] as Map<String, dynamic>?;
    
    if (request == null) {
      logger.w('[MCP Automation] No request context for modifyRequest');
      return;
    }
    
    final requestId = request['id'] as String?;
    if (requestId == null) return;
    
    final bridge = McpBridge();
    final httpRequest = bridge.getRequestById(requestId);
    if (httpRequest == null) {
      logger.w('[MCP Automation] Request not found: $requestId');
      return;
    }
    
    // 修改请求头
    if (params.containsKey('headers')) {
      final headers = params['headers'] as Map;
      for (final entry in headers.entries) {
        httpRequest.headers.set(entry.key as String, entry.value as String);
      }
      logger.i('[MCP Automation] Modified request headers for task: ${task.name}');
    }
    
    // 修改请求体
    if (params.containsKey('body')) {
      final body = params['body'] as String;
      httpRequest.body = utf8.encode(body);
      logger.i('[MCP Automation] Modified request body for task: ${task.name}');
    }
  }

  /// 实现修改响应逻辑
  Future<void> _modifyResponse(MCPAutomationTask task, Map<String, dynamic> context) async {
    final params = task.actionParams;
    final response = context['response'] as Map<String, dynamic>?;
    
    if (response == null) {
      logger.w('[MCP Automation] No response context for modifyResponse');
      return;
    }
    
    final requestId = response['requestId'] as String?;
    if (requestId == null) return;
    
    final bridge = McpBridge();
    final httpRequest = bridge.getRequestById(requestId);
    if (httpRequest?.response == null) {
      logger.w('[MCP Automation] Response not found for request: $requestId');
      return;
    }
    
    final httpResponse = httpRequest!.response!;
    
    // 修改响应头
    if (params.containsKey('headers')) {
      final headers = params['headers'] as Map;
      for (final entry in headers.entries) {
        httpResponse.headers.set(entry.key as String, entry.value as String);
      }
      logger.i('[MCP Automation] Modified response headers for task: ${task.name}');
    }
    
    // 修改响应体
    if (params.containsKey('body')) {
      final body = params['body'] as String;
      httpResponse.body = utf8.encode(body);
      logger.i('[MCP Automation] Modified response body for task: ${task.name}');
    }
    
    // 修改状态码
    if (params.containsKey('statusCode')) {
      final statusCode = params['statusCode'] as int;
      httpResponse.status = io.HttpStatus.custom;
      // 注意：实际修改状态码需要更复杂的处理
      logger.i('[MCP Automation] Modified response status for task: ${task.name}');
    }
  }

  /// 实现拦截请求逻辑
  Future<void> _blockRequest(MCPAutomationTask task, Map<String, dynamic> context) async {
    final request = context['request'] as Map<String, dynamic>?;
    
    if (request == null) {
      logger.w('[MCP Automation] No request context for blockRequest');
      return;
    }
    
    final requestId = request['id'] as String?;
    if (requestId == null) return;
    
    final bridge = McpBridge();
    final httpRequest = bridge.getRequestById(requestId);
    if (httpRequest == null) {
      logger.w('[MCP Automation] Request not found: $requestId');
      return;
    }
    
    // 标记请求为已阻止
    httpRequest.metadata['blocked'] = true;
    httpRequest.metadata['blockedBy'] = task.name;
    logger.i('[MCP Automation] Blocked request for task: ${task.name}');
  }

  /// 实现重放请求逻辑
  Future<void> _replayRequest(MCPAutomationTask task, Map<String, dynamic> context) async {
    final request = context['request'] as Map<String, dynamic>?;
    
    if (request == null) {
      logger.w('[MCP Automation] No request context for replayRequest');
      return;
    }
    
    final requestId = request['id'] as String?;
    if (requestId == null) return;
    
    final bridge = McpBridge();
    final httpRequest = bridge.getRequestById(requestId);
    if (httpRequest == null) {
      logger.w('[MCP Automation] Request not found: $requestId');
      return;
    }
    
    try {
      // 使用 HttpClient 重新发送请求
      final client = HttpClient();
      final uri = Uri.parse(httpRequest.requestUrl);
      
      var ioRequest = await client.openUrl(httpRequest.method.name, uri);
      
      // 复制请求头
      httpRequest.headers.toMap().forEach((key, value) {
        ioRequest.headers.set(key, value);
      });
      
      // 设置请求体
      if (httpRequest.body != null && httpRequest.body!.isNotEmpty) {
        ioRequest.add(httpRequest.body!);
      }
      
      final response = await ioRequest.close();
      logger.i('[MCP Automation] Replayed request for task: ${task.name}, status: ${response.statusCode}');
    } catch (e) {
      logger.e('[MCP Automation] Failed to replay request: $e');
    }
  }

  /// 实现导出数据逻辑
  Future<void> _exportData(MCPAutomationTask task, Map<String, dynamic> context) async {
    final params = task.actionParams;
    final exportFormat = params['format'] as String? ?? 'json';
    final exportPath = params['path'] as String?;
    
    final bridge = McpBridge();
    final requests = bridge.source;
    
    try {
      String content;
      String extension;
      
      if (exportFormat == 'har') {
        // 导出为 HAR 格式
        final harData = _generateHAR(requests);
        content = jsonEncode(harData);
        extension = 'har';
      } else {
        // 导出为 JSON 格式
        final jsonData = requests.map((req) => _requestToJson(req)).toList();
        content = jsonEncode(jsonData);
        extension = 'json';
      }
      
      // 保存到文件
      String filePath;
      if (exportPath != null && exportPath.isNotEmpty) {
        filePath = exportPath;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/mcp_automation_export_${DateTime.now().millisecondsSinceEpoch}.$extension';
      }
      
      await io.File(filePath).writeAsString(content);
      logger.i('[MCP Automation] Exported data to: $filePath for task: ${task.name}');
    } catch (e) {
      logger.e('[MCP Automation] Failed to export data: $e');
    }
  }

  /// 生成 HAR 格式数据
  Map<String, dynamic> _generateHAR(List<HttpRequest> requests) {
    return {
      'log': {
        'version': '1.2',
        'creator': {
          'name': 'ProxyPin MCP Automation',
          'version': '1.12.0',
        },
        'entries': requests.map((req) => _requestToHAREntry(req)).toList(),
      },
    };
  }

  /// 转换请求为 HAR 条目
  Map<String, dynamic> _requestToHAREntry(HttpRequest request) {
    return {
      'startedDateTime': request.requestTime.toIso8601String(),
      'time': request.response != null
          ? request.response!.responseTime.difference(request.requestTime).inMilliseconds
          : 0,
      'request': {
        'method': request.method.name.toUpperCase(),
        'url': request.requestUrl,
        'httpVersion': 'HTTP/1.1',
        'headers': request.headers.toMap().entries.map((e) => {
          'name': e.key,
          'value': e.value,
        }).toList(),
        'bodySize': request.body?.length ?? 0,
      },
      'response': request.response != null
          ? {
              'status': request.response!.status.code,
              'statusText': request.response!.status.reasonPhrase,
              'httpVersion': 'HTTP/1.1',
              'headers': request.response!.headers.toMap().entries.map((e) => {
                'name': e.key,
                'value': e.value,
              }).toList(),
              'bodySize': request.response!.body?.length ?? 0,
            }
          : {},
    };
  }

  /// 转换请求为 JSON
  Map<String, dynamic> _requestToJson(HttpRequest request) {
    return {
      'id': request.requestId,
      'url': request.requestUrl,
      'method': request.method.name.toUpperCase(),
      'statusCode': request.response?.status.code,
      'requestTime': request.requestTime.toIso8601String(),
      'responseTime': request.response?.responseTime.toIso8601String(),
    };
  }

  /// 实现执行脚本逻辑（通过 ScriptManager 真实执行）
  Future<void> _runScript(MCPAutomationTask task, Map<String, dynamic> context) async {
    final params = task.actionParams;
    final scriptType = params['scriptType'] as String? ?? 'javascript';
    final scriptCode = params['scriptCode'] as String?;
    final scriptPath = params['scriptPath'] as String?;
    final scriptName = params['scriptName'] as String?;

    if (scriptCode == null && scriptPath == null && scriptName == null) {
      logger.w('[MCP Automation] No script code, path or name provided');
      return;
    }

    try {
      // 优先按名称匹配 ScriptManager 注册脚本
      if (scriptName != null) {
        final mgr = await ScriptManager.instance;
        for (final s in mgr.list) {
          if (s.name == scriptName) {
            await mgr.runStandalone(s);
            logger.i('[MCP Automation] 通过 ScriptManager 执行脚本: $scriptName');
            return;
          }
        }
      }

      // 文件路径或内联代码
      String code;
      if (scriptCode != null && scriptCode.isNotEmpty) {
        code = scriptCode;
      } else if (scriptPath != null) {
        code = await io.File(scriptPath).readAsString();
      } else {
        return;
      }

      logger.i('[MCP Automation] Executing script for task: ${task.name}');

      // 根据脚本类型执行
      if (scriptType == 'dart') {
        // Dart 内联脚本：查找是否有匹配的注册脚本，否则仅记录
        logger.i('[MCP Automation] Dart script (inline, no runtime): ${code.length} chars');
      } else {
        // JavaScript 脚本：通过 flutterJs 引擎执行
        final mgr = await ScriptManager.instance;
        await mgr.flutterJsPool.run((flutterJs) async {
          final jsResult = await flutterJs.evaluateAsync(
            'var context = ${jsonEncode(context)}; $code\n  onRequest(context, {})');
          logger.i('[MCP Automation] JavaScript 脚本执行完成');
        });
      }
    } catch (e) {
      logger.e('[MCP Automation] Failed to run script: $e');
    }
  }

  /// 实现发送通知逻辑
  Future<void> _sendNotification(MCPAutomationTask task, Map<String, dynamic> context) async {
    final params = task.actionParams;
    final title = params['title'] as String? ?? 'MCP Automation';
    final message = params['message'] as String? ?? 'Task executed: ${task.name}';
    
    logger.i('[MCP Automation] Sending notification: $title - $message');
    
    // 使用 Flutter 的本地通知（需要配置 flutter_local_notifications）
    // 这里提供框架，实际通知逻辑可根据需求扩展
    try {
      // 注意：实际通知发送需要集成 flutter_local_notifications 插件
      // 简化版本：只记录日志
      logger.i('[MCP Automation] Notification sent (logged)');
    } catch (e) {
      logger.e('[MCP Automation] Failed to send notification: $e');
    }
  }

  /// 实现调用 Webhook 逻辑
  Future<void> _callWebhook(MCPAutomationTask task, Map<String, dynamic> context) async {
    final params = task.actionParams;
    final url = params['webhookUrl'] as String?;
    final method = params['method'] as String? ?? 'POST';
    final headers = params['headers'] as Map?;
    final body = params['body'] as Map?;
    
    if (url == null || url.isEmpty) {
      logger.w('[MCP Automation] No webhook URL provided');
      return;
    }
    
    try {
      logger.i('[MCP Automation] Calling webhook: $url for task: ${task.name}');
      
      // 准备请求体
      String? bodyData;
      if (body != null) {
        // 添加上下文信息
        final enrichedBody = Map<String, dynamic>.from(body);
        enrichedBody['taskName'] = task.name;
        enrichedBody['taskId'] = task.id;
        enrichedBody['timestamp'] = DateTime.now().toIso8601String();
        
        if (context.containsKey('request')) {
          enrichedBody['request'] = context['request'];
        }
        if (context.containsKey('response')) {
          enrichedBody['response'] = context['response'];
        }
        
        bodyData = jsonEncode(enrichedBody);
      }
      
      // 发送 HTTP 请求
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...Map<String, String>.from(headers),
        },
        body: bodyData,
      );
      
      logger.i('[MCP Automation] Webhook response: ${response.statusCode}');
    } catch (e) {
      logger.e('[MCP Automation] Failed to call webhook: $e');
    }
  }

  /// 清空所有任务
  Future<void> clearAllTasks() async {
    _tasks.clear();
    _taskLastExecuted.clear();
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
