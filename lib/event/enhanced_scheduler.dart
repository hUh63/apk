/*
 * 增强定时调度器 - 支持 Cron 表达式、一次性任务、周期性任务
 */

import 'dart:async';
import 'dart:io';

/// 任务回调
typedef TaskCallback = Future<void> Function();

/// 任务状态
enum TaskStatus { pending, running, completed, failed, cancelled }

/// 调度任务
class ScheduledTask {
  final String id;
  final String name;
  final TaskCallback callback;
  final String? cronExpression;
  final Duration? interval;
  final DateTime? executeAt;
  final bool repeat;
  final int maxRetries;
  TaskStatus _status = TaskStatus.pending;
  DateTime? _lastExecuted;
  DateTime? _nextExecution;
  int _runCount = 0;
  int _failCount = 0;

  ScheduledTask({
    required this.id,
    required this.name,
    required this.callback,
    this.cronExpression,
    this.interval,
    this.executeAt,
    this.repeat = false,
    this.maxRetries = 3,
  }) {
    _nextExecution = executeAt;
  }

  TaskStatus get status => _status;
  DateTime? get lastExecuted => _lastExecuted;
  DateTime? get nextExecution => _nextExecution;
  int get runCount => _runCount;
  int get failCount => _failCount;

  void _markRunning() {
    _status = TaskStatus.running;
  }

  void _markCompleted() {
    _status = TaskStatus.completed;
    _lastExecuted = DateTime.now();
    _runCount++;
  }

  void _markFailed() {
    _status = TaskStatus.failed;
    _failCount++;
  }

  void _markCancelled() {
    _status = TaskStatus.cancelled;
  }

  void _scheduleNext() {
    if (cronExpression != null) {
      _nextExecution = _parseCronNext(cronExpression!);
    } else if (interval != null && repeat) {
      _nextExecution = DateTime.now().add(interval!);
    } else {
      _nextExecution = null;
    }
  }

  /// 简单 Cron 解析 (支持 * / , -)
  DateTime? _parseCronNext(String cron) {
    // 简化实现：只支持分钟级别
    // 格式：分 时 日 月 星期
    try {
      final parts = cron.trim().split(RegExp(r'\s+'));
      if (parts.length != 5) return null;

      final now = DateTime.now();
      var minute = _parseCronField(parts[0], 0, 59, now.minute);
      var hour = _parseCronField(parts[1], 0, 23, now.hour);
      var day = _parseCronField(parts[2], 1, 31, now.day);
      var month = _parseCronField(parts[3], 1, 12, now.month);

      // 如果当前时间已过，则计算下一个周期
      if (minute <= now.minute && hour <= now.hour && day <= now.day && month <= now.month) {
        hour++;
        if (hour > 23) {
          hour = 0;
          day++;
        }
      }

      return DateTime(now.year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  int _parseCronField(String field, int min, int max, int current) {
    if (field == '*') return current;
    if (field.contains('/')) {
      // */5 表示每 5 个单位
      final step = int.parse(field.split('/').last);
      return ((current ~/ step) + 1) * step;
    }
    if (field.contains(',')) {
      // 1,3,5 表示特定值
      final values = field.split(',').map(int.parse).toList();
      for (final v in values) {
        if (v > current) return v;
      }
      return values.first;
    }
    if (field.contains('-')) {
      // 1-5 表示范围
      final parts = field.split('-');
      final start = int.parse(parts.first);
      return start;
    }
    return int.parse(field);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cronExpression': cronExpression,
        'interval': interval?.inSeconds,
        'executeAt': executeAt?.toIso8601String(),
        'repeat': repeat,
        'status': _status.name,
        'lastExecuted': _lastExecuted?.toIso8601String(),
        'nextExecution': _nextExecution?.toIso8601String(),
        'runCount': _runCount,
        'failCount': _failCount,
      };
}

/// 增强定时调度器
class EnhancedScheduler {
  static final EnhancedScheduler _instance = EnhancedScheduler._internal();
  factory EnhancedScheduler() => _instance;
  EnhancedScheduler._internal();

  final Map<String, ScheduledTask> _tasks = {};
  Timer? _timer;
  bool _isRunning = false;

  /// 添加一次性任务
  String addOnce({
    required String name,
    required DateTime executeAt,
    required TaskCallback callback,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = ScheduledTask(
      id: id,
      name: name,
      callback: callback,
      executeAt: executeAt,
      repeat: false,
    );
    _tasks[id] = task;
    _startScheduler();
    return id;
  }

  /// 添加周期性任务
  String addPeriodic({
    required String name,
    required Duration interval,
    required TaskCallback callback,
    bool repeat = true,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = ScheduledTask(
      id: id,
      name: name,
      callback: callback,
      interval: interval,
      executeAt: DateTime.now().add(interval),
      repeat: repeat,
    );
    _tasks[id] = task;
    _startScheduler();
    return id;
  }

  /// 添加 Cron 任务
  String addCron({
    required String name,
    required String cronExpression,
    required TaskCallback callback,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = ScheduledTask(
      id: id,
      name: name,
      callback: callback,
      cronExpression: cronExpression,
      repeat: true,
    );
    task._scheduleNext();
    _tasks[id] = task;
    _startScheduler();
    return id;
  }

  /// 取消任务
  bool cancelTask(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      task._markCancelled();
      return true;
    }
    return false;
  }

  /// 获取任务列表
  List<ScheduledTask> getTasks() {
    return _tasks.values.toList();
  }

  /// 获取任务详情
  ScheduledTask? getTask(String taskId) {
    return _tasks[taskId];
  }

  /// 清空所有任务
  void clear() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _tasks.clear();
  }

  void _startScheduler() {
    if (_isRunning) return;
    _isRunning = true;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkTasks());
  }

  Future<void> _checkTasks() async {
    final now = DateTime.now();

    for (final task in _tasks.values) {
      if (task.status == TaskStatus.cancelled) continue;
      if (task.nextExecution == null) continue;

      if (task.nextExecution!.isBefore(now) || task.nextExecution!.isAtSameMomentAs(now)) {
        await _executeTask(task);
      }
    }
  }

  Future<void> _executeTask(ScheduledTask task) async {
    task._markRunning();

    try {
      await task.callback();
      task._markCompleted();
      task._scheduleNext();

      if (!task.repeat && task.nextExecution == null) {
        task._markCancelled();
      }
    } catch (e) {
      task._markFailed();
      print('Scheduler: Task "${task.name}" failed: $e');

      if (task.failCount < task.maxRetries) {
        // 重试：5 秒后
        task._nextExecution = DateTime.now().add(const Duration(seconds: 5));
      } else {
        task._markCancelled();
      }
    }
  }

  /// 关闭调度器
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _tasks.clear();
  }
}
