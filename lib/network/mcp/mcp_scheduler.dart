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
import 'package:proxypin/network/util/logger.dart';

/// 无参数无返回值的回调类型
typedef VoidCallback = void Function();

/// MCP 定时任务调度器
/// 支持一次性任务和每日重复任务
class McpScheduler {
  static final McpScheduler _instance = McpScheduler._internal();
  factory McpScheduler() => _instance;
  McpScheduler._internal();

  final List<ScheduledTask> _tasks = [];
  Timer? _checkTimer;

  /// 添加定时任务
  void scheduleTask({
    required String name,
    required DateTime executeAt,
    required VoidCallback action,
    bool repeatDaily = false,
  }) {
    final task = ScheduledTask(
      name: name,
      executeAt: executeAt,
      action: action,
      repeatDaily: repeatDaily,
    );
    _tasks.add(task);
    logger.i('添加定时任务：$name，执行时间：$executeAt，重复：$repeatDaily');
    
    // 启动检查定时器（如果还未启动）
    _startCheckTimer();
  }

  /// 启动检查定时器
  void _startCheckTimer() {
    if (_checkTimer != null && _checkTimer!.isActive) return;
    
    _checkTimer = Timer.periodic(Duration(seconds: 10), (_) => _checkTasks());
    logger.d('定时任务检查器已启动');
  }

  /// 检查并执行到期的任务
  void _checkTasks() {
    final now = DateTime.now();
    
    for (final task in _tasks) {
      if (task.isCancelled) continue;
      
      if (now.isAfter(task.executeAt) || now.isAtSameMomentAs(task.executeAt)) {
        // 任务到期，执行
        try {
          logger.i('执行定时任务：${task.name}');
          task.action();
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
          } else {
            // 一次性任务，标记为已取消
            task.isCancelled = true;
            logger.d('一次性任务 ${task.name} 已完成');
          }
        } catch (e) {
          logger.e('执行定时任务 ${task.name} 失败', error: e);
        }
      }
    }
    
    // 清理已取消的任务
    _tasks.removeWhere((task) => task.isCancelled);
  }

  /// 取消所有任务
  void cancelAll() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _tasks.clear();
    logger.i('已取消所有定时任务');
  }

  /// 获取任务列表
  List<ScheduledTask> get tasks => List.unmodifiable(_tasks);
}

/// 定时任务
class ScheduledTask {
  final String name;
  DateTime executeAt;
  final VoidCallback action;
  final bool repeatDaily;
  DateTime? lastExecuted;
  bool isCancelled = false;

  ScheduledTask({
    required this.name,
    required this.executeAt,
    required this.action,
    this.repeatDaily = false,
  });

  @override
  String toString() {
    return 'ScheduledTask(name: $name, executeAt: $executeAt, repeatDaily: $repeatDaily)';
  }
}
