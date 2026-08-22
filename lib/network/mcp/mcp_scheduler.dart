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
import 'package:proxypin/network/util/logger.dart';
import 'package:proxypin/storage/path.dart';

/// 无参数无返回值的回调类型
typedef VoidCallback = void Function();

/// 可序列化任务执行器：UI 层启动时注册一次。
/// 把"动作描述"(type+参数) 还原为真实执行，使定时任务可跨重启持久化。
typedef TaskActionExecutor = Future<void> Function(Map<String, dynamic> descriptor);

/// MCP 定时任务调度器
/// 支持一次性任务和每日重复任务，可持久化到 mcp_tasks.json
class McpScheduler {
  static final McpScheduler _instance = McpScheduler._internal();
  factory McpScheduler() => _instance;
  McpScheduler._internal();

  final List<ScheduledTask> _tasks = [];
  Timer? _checkTimer;
  TaskActionExecutor? _executor;

  /// 注册动作执行器（UI 层启动时调用一次）
  void setActionExecutor(TaskActionExecutor executor) => _executor = executor;

  /// 添加定时任务
  /// [action] 仅本会话即时触发（闭包不可序列化）；[actionDescriptor] 可持久化，
  /// 重启加载后由 [setActionExecutor] 注册的执行器触发。二者任一非空即可。
  void scheduleTask({
    required String name,
    required DateTime executeAt,
    VoidCallback? action,
    Map<String, dynamic>? actionDescriptor,
    bool repeatDaily = false,
  }) {
    final task = ScheduledTask(
      name: name,
      executeAt: executeAt,
      action: action,
      actionDescriptor: actionDescriptor,
      repeatDaily: repeatDaily,
    );
    _tasks.add(task);
    logger.i('添加定时任务：$name，执行时间：$executeAt，重复：$repeatDaily');

    _startCheckTimer();
  }

  /// 启动检查定时器
  void _startCheckTimer() {
    if (_checkTimer != null && _checkTimer!.isActive) return;

    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkTasks());
    logger.d('定时任务检查器已启动');
  }

  /// 检查并执行到期的任务
  Future<void> _checkTasks() async {
    final now = DateTime.now();

    for (final task in _tasks) {
      if (task.isCancelled) continue;

      if (now.isAfter(task.executeAt) || now.isAtSameMomentAs(task.executeAt)) {
        // 任务到期，执行
        try {
          logger.i('执行定时任务：${task.name}');
          await _runTask(task);
          task.lastExecuted = now;

          if (task.repeatDaily) {
            // 设置为明天的同一时间
            task.executeAt = DateTime(
              now.year,
              now.month,
              now.day + 1,
              task.executeAt.hour,
              task.executeAt.minute,
              task.executeAt.second,
            );
            logger.d('定时任务 ${task.name} 下次执行时间：${task.executeAt}');
            await saveTasks();
          } else {
            // 一次性任务，标记为已取消
            task.isCancelled = true;
            logger.d('一次性任务 ${task.name} 已完成');
            await saveTasks();
          }
        } catch (e) {
          logger.e('执行定时任务 ${task.name} 失败', error: e);
        }
      }
    }

    // 清理已取消的任务
    _tasks.removeWhere((task) => task.isCancelled);
  }

  /// 执行单个任务：优先闭包，否则用执行器跑动作描述
  Future<void> _runTask(ScheduledTask task) async {
    if (task.action != null) {
      task.action!();
      return;
    }
    if (task.actionDescriptor != null) {
      if (_executor != null) {
        await _executor!(task.actionDescriptor!);
      } else {
        logger.w('任务 ${task.name} 有动作描述但未注册执行器，跳过');
      }
    }
  }

  /// 取消所有任务
  void cancelAll() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _tasks.clear();
    logger.i('已取消所有定时任务');
  }

  /// 取消单个定时任务（按名称，避免误删全部）
  void cancelTask(String name) {
    for (final task in _tasks) {
      if (task.name == name && !task.isCancelled) {
        task.isCancelled = true;
      }
    }
    _tasks.removeWhere((task) => task.isCancelled);
    logger.i('已取消定时任务：$name');
  }

  /// 获取任务列表
  List<ScheduledTask> get tasks => List.unmodifiable(_tasks);

  /// 持久化（仅持久化带动作描述的任务，闭包无法序列化）
  Future<void> saveTasks() async {
    try {
      final file = await Paths.getPath('mcp_tasks.json');
      final data = _tasks
          .where((t) => t.actionDescriptor != null && !t.isCancelled)
          .map((t) => t.toJson())
          .toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e, st) {
      logger.e('保存定时任务失败', error: e, stackTrace: st);
    }
  }

  /// 启动时加载持久化任务（动作描述 → 由执行器触发）
  Future<void> loadTasks() async {
    try {
      final file = await Paths.getPath('mcp_tasks.json');
      if (!await file.exists()) return;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;
      final list = jsonDecode(content) as List<dynamic>;
      final now = DateTime.now();
      for (final e in list) {
        final t = ScheduledTask.fromJson(e as Map<String, dynamic>);
        if (t.isCancelled) continue;
        // 跳过已过期的非重复任务
        if (!t.repeatDaily && t.executeAt.isBefore(now)) continue;
        _tasks.add(t);
      }
      _startCheckTimer();
      logger.i('已加载 ${_tasks.length} 个持久化定时任务');
    } catch (e, st) {
      logger.e('加载定时任务失败', error: e, stackTrace: st);
    }
  }
}

/// 定时任务
class ScheduledTask {
  final String name;
  DateTime executeAt;
  final VoidCallback? action; // 本会话闭包（不持久化）
  final Map<String, dynamic>? actionDescriptor; // 可序列化动作描述
  final bool repeatDaily;
  DateTime? lastExecuted;
  bool isCancelled = false;

  ScheduledTask({
    required this.name,
    required this.executeAt,
    this.action,
    this.actionDescriptor,
    this.repeatDaily = false,
    this.lastExecuted,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'executeAt': executeAt.toIso8601String(),
        'repeatDaily': repeatDaily,
        if (actionDescriptor != null) 'action': actionDescriptor,
        if (lastExecuted != null) 'lastExecuted': lastExecuted!.toIso8601String(),
      };

  factory ScheduledTask.fromJson(Map<String, dynamic> json) => ScheduledTask(
        name: json['name'] as String,
        executeAt: DateTime.parse(json['executeAt'] as String),
        actionDescriptor: json['action'] as Map<String, dynamic>?,
        repeatDaily: json['repeatDaily'] == true,
        lastExecuted: json['lastExecuted'] == null ? null : DateTime.tryParse(json['lastExecuted'] as String),
      );

  @override
  String toString() {
    return 'ScheduledTask(name: $name, executeAt: $executeAt, repeatDaily: $repeatDaily)';
  }
}
