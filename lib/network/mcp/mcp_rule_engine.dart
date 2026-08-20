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
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/util/logger.dart';

/// 规则优先级
enum RulePriority { low, normal, high, critical }

/// 条件类型
enum ConditionType {
  httpRequest,
  networkStatus,
  proxyStatus,
  systemStatus,
  custom,
}

/// 操作符
enum Operator {
  equals,
  notEquals,
  greaterThan,
  lessThan,
  greaterThanOrEqual,
  lessThanOrEqual,
  contains,
  startsWith,
  endsWith,
  matches,
  inList,
  notInList,
  exists,
  notExists,
}

/// 动作类型
enum ActionType {
  log,
  notify,
  stopCapture,
  startCapture,
  exportData,
  executeScript,
  sendWebhook,
  custom,
}

/// 动作回调类型
typedef ActionCallback = Future<void> Function(dynamic context, Map<String, dynamic>? params);

/// 规则执行记录
class RuleExecutionRecord {
  final String ruleId;
  final DateTime timestamp;
  final bool matched;
  final String? action;
  
  RuleExecutionRecord(this.ruleId, this.matched, this.action) 
      : timestamp = DateTime.now();
}

/// 规则类
class Rule {
  final String id;
  final String name;
  final String description;
  final List<Condition> conditions;
  final List<Action> actions;
  final RulePriority priority;
  final bool enabled;
  final DateTime? expiresAt;

  Rule({
    required this.id,
    required this.name,
    this.description = '',
    required this.conditions,
    required this.actions,
    this.priority = RulePriority.normal,
    this.enabled = true,
    this.expiresAt,
  });

  /// 检查规则是否过期
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// 检查规则是否可用
  bool get isAvailable => enabled && !isExpired;
}

/// 条件类
class Condition {
  final ConditionType type;
  final String field;
  final Operator operator;
  final dynamic value;

  Condition({
    required this.type,
    required this.field,
    required this.operator,
    required this.value,
  });

  /// 评估条件是否匹配
  bool evaluate(dynamic context) {
    final actualValue = _getFieldValue(context, field);
    
    switch (operator) {
      case Operator.equals:
        return actualValue == value;
      case Operator.notEquals:
        return actualValue != value;
      case Operator.greaterThan:
        return _compare(actualValue, value) > 0;
      case Operator.lessThan:
        return _compare(actualValue, value) < 0;
      case Operator.greaterThanOrEqual:
        return _compare(actualValue, value) >= 0;
      case Operator.lessThanOrEqual:
        return _compare(actualValue, value) <= 0;
      case Operator.contains:
        return actualValue.toString().contains(value.toString());
      case Operator.startsWith:
        return actualValue.toString().startsWith(value.toString());
      case Operator.endsWith:
        return actualValue.toString().endsWith(value.toString());
      case Operator.matches:
        if (value is RegExp) {
          return value.hasMatch(actualValue.toString());
        }
        return RegExp(value.toString()).hasMatch(actualValue.toString());
      case Operator.inList:
        if (value is List) {
          return value.contains(actualValue);
        }
        return false;
      case Operator.notInList:
        if (value is List) {
          return !value.contains(actualValue);
        }
        return true;
      case Operator.exists:
        return actualValue != null;
      case Operator.notExists:
        return actualValue == null;
    }
  }

  /// 获取字段值
  dynamic _getFieldValue(dynamic context, String field) {
    if (context == null) return null;
    
    // 支持嵌套字段，如 "request.headers.content-type"
    final parts = field.split('.');
    dynamic result = context;
    
    for (final part in parts) {
      if (result is Map) {
        result = result[part];
      } else if (result is HttpRequest) {
        result = _getHttpRequestField(result, part);
      } else {
        return null;
      }
      
      if (result == null) break;
    }
    
    return result;
  }

  /// 获取 HttpRequest 字段
  dynamic _getHttpRequestField(HttpRequest request, String field) {
    switch (field) {
      case 'url':
        return request.requestUrl;
      case 'method':
        return request.method.name;
      case 'statusCode':
        return request.response?.status.code;
      case 'duration':
        return request.response != null 
            ? request.response!.responseTime.difference(request.requestTime).inMilliseconds 
            : 0;
      case 'requestSize':
        return request.contentLength;
      case 'responseSize':
        return request.response?.contentLength ?? 0;
      case 'host':
        return request.hostAndPort?.host ?? request.requestUri?.host;
      case 'path':
        return request.path;
      case 'contentType':
        return request.headers.contentType;
      case 'responseContentType':
        return request.response?.headers.contentType;
      default:
        return null;
    }
  }

  /// 比较两个值
  int _compare(dynamic a, dynamic b) {
    if (a is num && b is num) {
      return a.compareTo(b);
    }
    if (a is DateTime && b is DateTime) {
      return a.compareTo(b);
    }
    return a.toString().compareTo(b.toString());
  }
}

/// 动作类
class Action {
  final ActionType type;
  final String? target;
  final Map<String, dynamic>? parameters;
  final ActionCallback? callback;

  Action({
    required this.type,
    this.target,
    this.parameters,
    this.callback,
  });

  /// 执行动作
  Future<void> execute(dynamic context) async {
    if (callback != null) {
      await callback!(context, parameters);
    }
  }
}

/// MCP 条件规则引擎
/// 支持基于条件的自动化决策和资源管理
/// @author wanghongen
/// 2026-08-12
class McpRuleEngine {
  static final McpRuleEngine _instance = McpRuleEngine._internal();
  factory McpRuleEngine() => _instance;
  McpRuleEngine._internal();

  // 规则列表
  final List<Rule> _rules = [];
  
  // 规则执行历史
  final List<RuleExecutionRecord> _executionHistory = [];
  static const int _maxHistorySize = 50;

  // ==================== 规则管理 ====================

  /// 添加规则
  void addRule(Rule rule) {
    _rules.add(rule);
    logger.i('添加规则：${rule.name} (${rule.id})');
    _sortRules();
  }

  /// 移除规则
  void removeRule(String ruleId) {
    _rules.removeWhere((rule) => rule.id == ruleId);
    logger.d('移除规则：$ruleId');
  }

  /// 启用规则
  void enableRule(String ruleId) {
    final rule = _rules.firstWhere((r) => r.id == ruleId, orElse: () => throw Exception('Rule not found'));
    // 由于规则是不可变的，需要替换
    final index = _rules.indexWhere((r) => r.id == ruleId);
    if (index != -1) {
      _rules[index] = Rule(
        id: rule.id,
        name: rule.name,
        description: rule.description,
        conditions: rule.conditions,
        actions: rule.actions,
        priority: rule.priority,
        enabled: true,
        expiresAt: rule.expiresAt,
      );
    }
  }

  /// 禁用规则
  void disableRule(String ruleId) {
    final index = _rules.indexWhere((r) => r.id == ruleId);
    if (index != -1) {
      final rule = _rules[index];
      _rules[index] = Rule(
        id: rule.id,
        name: rule.name,
        description: rule.description,
        conditions: rule.conditions,
        actions: rule.actions,
        priority: rule.priority,
        enabled: false,
        expiresAt: rule.expiresAt,
      );
    }
  }

  /// 按优先级排序规则
  void _sortRules() {
    _rules.sort((a, b) {
      // 先按启用状态排序
      if (a.isAvailable != b.isAvailable) {
        return a.isAvailable ? -1 : 1;
      }
      // 再按优先级排序
      return b.priority.index - a.priority.index;
    });
  }

  /// 获取所有规则
  List<Rule> getRules() => List.unmodifiable(_rules);

  /// 获取规则列表（只读）
  List<Rule> get rules => List.unmodifiable(_rules);

  /// 清除所有规则
  void clearRules() {
    _rules.clear();
    logger.d('清除所有规则');
  }

  // ==================== 规则评估 ====================

  /// 评估并执行规则
  Future<void> evaluate(dynamic context) async {
    for (final rule in _rules) {
      if (!rule.isAvailable) continue;

      // 检查所有条件是否匹配
      final allMatched = rule.conditions.every((condition) => condition.evaluate(context));
      
      // 记录执行历史
      _executionHistory.add(RuleExecutionRecord(rule.id, allMatched, allMatched ? 'executed' : 'skipped'));
      if (_executionHistory.length > _maxHistorySize) {
        _executionHistory.removeAt(0);
      }

      if (allMatched) {
        logger.i('规则匹配：${rule.name}');
        
        // 执行所有动作
        for (final action in rule.actions) {
          try {
            await action.execute(context);
          } catch (e, stackTrace) {
            logger.e('规则动作执行失败：${rule.name}', error: e, stackTrace: stackTrace);
          }
        }
        
        // 如果规则是 critical 优先级，执行后停止后续规则评估
        if (rule.priority == RulePriority.critical) {
          break;
        }
      }
    }
  }

  /// 获取执行历史
  List<RuleExecutionRecord> getExecutionHistory({int? limit}) {
    if (limit == null) return List.unmodifiable(_executionHistory);
    final start = _executionHistory.length - limit.clamp(0, _executionHistory.length);
    return _executionHistory.sublist(start);
  }

  // ==================== 预定义规则构建器 ====================

  /// 创建 HTTP 请求规则
  static Rule createHttpRequestRule({
    required String id,
    required String name,
    String? urlPattern,
    String? method,
    int? minStatusCode,
    int? maxStatusCode,
    int? minDuration,
    int? maxDuration,
    required List<Action> actions,
    RulePriority priority = RulePriority.normal,
  }) {
    final conditions = <Condition>[];
    
    if (urlPattern != null) {
      conditions.add(Condition(
        type: ConditionType.httpRequest,
        field: 'url',
        operator: Operator.matches,
        value: RegExp(urlPattern),
      ));
    }
    
    if (method != null) {
      conditions.add(Condition(
        type: ConditionType.httpRequest,
        field: 'method',
        operator: Operator.equals,
        value: method,
      ));
    }
    
    if (minStatusCode != null) {
      conditions.add(Condition(
        type: ConditionType.httpRequest,
        field: 'statusCode',
        operator: Operator.greaterThanOrEqual,
        value: minStatusCode,
      ));
    }
    
    if (maxStatusCode != null) {
      conditions.add(Condition(
        type: ConditionType.httpRequest,
        field: 'statusCode',
        operator: Operator.lessThanOrEqual,
        value: maxStatusCode,
      ));
    }
    
    if (minDuration != null) {
      conditions.add(Condition(
        type: ConditionType.httpRequest,
        field: 'duration',
        operator: Operator.greaterThanOrEqual,
        value: minDuration,
      ));
    }
    
    if (maxDuration != null) {
      conditions.add(Condition(
        type: ConditionType.httpRequest,
        field: 'duration',
        operator: Operator.lessThanOrEqual,
        value: maxDuration,
      ));
    }

    return Rule(
      id: id,
      name: name,
      conditions: conditions,
      actions: actions,
      priority: priority,
    );
  }

  /// 创建资源管理规则
  static Rule createResourceManagementRule({
    required String id,
    required String name,
    int? maxMemoryUsage,
    int? maxCaptureCount,
    int? maxFileSize,
    required List<Action> actions,
  }) {
    final conditions = <Condition>[];
    
    if (maxMemoryUsage != null) {
      conditions.add(Condition(
        type: ConditionType.systemStatus,
        field: 'memoryUsage',
        operator: Operator.greaterThan,
        value: maxMemoryUsage,
      ));
    }
    
    if (maxCaptureCount != null) {
      conditions.add(Condition(
        type: ConditionType.systemStatus,
        field: 'captureCount',
        operator: Operator.greaterThan,
        value: maxCaptureCount,
      ));
    }
    
    if (maxFileSize != null) {
      conditions.add(Condition(
        type: ConditionType.systemStatus,
        field: 'diskUsage',
        operator: Operator.greaterThan,
        value: maxFileSize,
      ));
    }

    return Rule(
      id: id,
      name: name,
      conditions: conditions,
      actions: actions,
      priority: RulePriority.high,
    );
  }
}

/// 使用示例
class McpRuleEngineExample {
  /// 示例：自动记录慢请求
  static void setupSlowRequestLogging() {
    final engine = McpRuleEngine();
    
    final rule = McpRuleEngine.createHttpRequestRule(
      id: 'slow_request_log',
      name: '慢请求日志',
      minDuration: 5000, // 超过 5 秒
      actions: [
        Action(
          type: ActionType.log,
          parameters: {'level': 'warning', 'message': '检测到慢请求'},
        ),
      ],
    );
    
    engine.addRule(rule);
  }

  /// 示例：自动导出错误请求
  static void setupErrorExport() {
    final engine = McpRuleEngine();
    
    final rule = McpRuleEngine.createHttpRequestRule(
      id: 'error_export',
      name: '错误请求自动导出',
      minStatusCode: 400,
      actions: [
        Action(
          type: ActionType.exportData,
          parameters: {'format': 'har', 'autoSave': true},
        ),
      ],
    );
    
    engine.addRule(rule);
  }

  /// 示例：内存保护规则
  static void setupMemoryProtection() {
    final engine = McpRuleEngine();
    
    final rule = McpRuleEngine.createResourceManagementRule(
      id: 'memory_protection',
      name: '内存保护',
      maxMemoryUsage: 500, // MB
      actions: [
        Action(
          type: ActionType.log,
          parameters: {'message': '内存使用过高，自动清理缓存'},
        ),
        Action(
          type: ActionType.custom,
          callback: (context, params) async {
            // 调用清理缓存的逻辑
            logger.i('执行内存清理');
          },
        ),
      ],
    );
    
    engine.addRule(rule);
  }

  /// 示例：自动停止大文件下载
  static void setupLargeFileBlock() {
    final engine = McpRuleEngine();
    
    final rule = McpRuleEngine.createHttpRequestRule(
      id: 'large_file_block',
      name: '大文件下载拦截',
      actions: [
        Action(
          type: ActionType.custom,
          callback: (context, params) async {
            if (context is HttpRequest) {
              final size = context.response?.contentLength ?? 0;
              if (size > 100 * 1024 * 1024) { // 100MB
                logger.w('拦截大文件下载：${context.requestUrl}');
              }
            }
          },
        ),
      ],
    );
    
    engine.addRule(rule);
  }
}
