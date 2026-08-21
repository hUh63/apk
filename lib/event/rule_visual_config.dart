/*
 * 可视化规则配置器 - 图形化规则编辑
 * 支持条件拖拽、逻辑组合、实时预览
 */

import 'package:flutter/material.dart';

/// 条件类型枚举
enum ConditionType {
  httpRequest,
  networkStatus,
  proxyStatus,
  systemStatus,
  custom,
}

/// 操作符类型
enum OperatorType {
  equals,
  notEquals,
  contains,
  startsWith,
  endsWith,
  matches,
  greaterThan,
  lessThan,
  inList,
  exists,
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

/// 规则优先级
enum RulePriority {
  low,
  normal,
  high,
  critical,
}

/// 条件模型
class RuleCondition {
  String id;
  ConditionType type;
  String field;
  OperatorType operator;
  dynamic value;
  bool enabled;

  RuleCondition({
    required this.id,
    required this.type,
    required this.field,
    required this.operator,
    required this.value,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'field': field,
        'operator': operator.name,
        'value': value,
        'enabled': enabled,
      };

  static RuleCondition fromJson(Map<String, dynamic> json) => RuleCondition(
        id: json['id'] as String,
        type: ConditionType.values.firstWhere((e) => e.name == json['type']),
        field: json['field'] as String,
        operator: OperatorType.values.firstWhere((e) => e.name == json['operator']),
        value: json['value'],
        enabled: json['enabled'] as bool? ?? true,
      );
}

/// 动作模型
class RuleAction {
  String id;
  ActionType type;
  Map<String, dynamic> config;
  bool enabled;

  RuleAction({
    required this.id,
    required this.type,
    required this.config,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'config': config,
        'enabled': enabled,
      };

  static RuleAction fromJson(Map<String, dynamic> json) => RuleAction(
        id: json['id'] as String,
        type: ActionType.values.firstWhere((e) => e.name == json['type']),
        config: Map<String, dynamic>.from(json['config'] as Map),
        enabled: json['enabled'] as bool? ?? true,
      );
}

/// 规则模型
class VisualRule {
  String id;
  String name;
  String description;
  List<RuleCondition> conditions;
  List<RuleAction> actions;
  RulePriority priority;
  bool enabled;
  DateTime? expiresAt;
  DateTime createdAt;
  DateTime updatedAt;

  VisualRule({
    required this.id,
    required this.name,
    required this.description,
    required this.conditions,
    required this.actions,
    this.priority = RulePriority.normal,
    this.enabled = true,
    this.expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 条件逻辑 (AND/OR)
  String conditionLogic = 'AND';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'conditionLogic': conditionLogic,
        'priority': priority.name,
        'enabled': enabled,
        'expiresAt': expiresAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static VisualRule fromJson(Map<String, dynamic> json) => VisualRule(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        conditions: (json['conditions'] as List).map((c) => RuleCondition.fromJson(c)).toList(),
        actions: (json['actions'] as List).map((a) => RuleAction.fromJson(a)).toList(),
        priority: RulePriority.values.firstWhere((e) => e.name == json['priority']),
        enabled: json['enabled'] as bool? ?? true,
        expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      )..conditionLogic = json['conditionLogic'] as String? ?? 'AND';
}

/// 规则验证器
class RuleValidator {
  static String? validate(VisualRule rule) {
    if (rule.name.trim().isEmpty) {
      return '规则名称不能为空';
    }

    if (rule.conditions.isEmpty) {
      return '至少需要一个条件';
    }

    if (rule.actions.isEmpty) {
      return '至少需要一个动作';
    }

    for (final condition in rule.conditions) {
      if (!condition.enabled) continue;
      if (condition.field.trim().isEmpty) {
        return '条件字段不能为空';
      }
    }

    for (final action in rule.actions) {
      if (!action.enabled) continue;
      if (action.type == ActionType.executeScript) {
        if (action.config['scriptPath'] == null || action.config['scriptPath'].toString().trim().isEmpty) {
          return '脚本动作需要指定脚本路径';
        }
      }
      if (action.type == ActionType.sendWebhook) {
        if (action.config['url'] == null || action.config['url'].toString().trim().isEmpty) {
          return 'Webhook 动作需要指定 URL';
        }
      }
    }

    return null;
  }

  static bool validateCondition(RuleCondition condition) {
    switch (condition.operator) {
      case OperatorType.inList:
        return condition.value is List && (condition.value as List).isNotEmpty;
      case OperatorType.matches:
        try {
          RegExp(condition.value.toString());
          return true;
        } catch (e) {
          return false;
        }
      default:
        return condition.value != null;
    }
  }
}

/// 规则预览生成器
class RulePreviewGenerator {
  static String generatePreview(VisualRule rule) {
    final buffer = StringBuffer();

    buffer.writeln('**规则**: ${rule.name}');
    if (rule.description.isNotEmpty) {
      buffer.writeln('**描述**: ${rule.description}');
    }
    buffer.writeln();

    // 条件预览
    buffer.writeln('**当满足以下条件时** (${rule.conditionLogic}):');
    for (final condition in rule.conditions.where((c) => c.enabled)) {
      buffer.writeln('  - ${_formatCondition(condition)}');
    }
    buffer.writeln();

    // 动作预览
    buffer.writeln('**执行以下动作**:');
    for (final action in rule.actions.where((a) => a.enabled)) {
      buffer.writeln('  - ${_formatAction(action)}');
    }

    return buffer.toString();
  }

  static String _formatCondition(RuleCondition condition) {
    final fieldNames = {
      'url': 'URL',
      'method': '方法',
      'statusCode': '状态码',
      'responseTime': '响应时间',
      'host': '域名',
      'path': '路径',
      'contentType': 'Content-Type',
    };

    final operatorNames = {
      OperatorType.equals: '等于',
      OperatorType.notEquals: '不等于',
      OperatorType.contains: '包含',
      OperatorType.startsWith: '以...开始',
      OperatorType.endsWith: '以...结束',
      OperatorType.matches: '匹配正则',
      OperatorType.greaterThan: '大于',
      OperatorType.lessThan: '小于',
      OperatorType.inList: '在列表中',
      OperatorType.exists: '存在',
    };

    final field = fieldNames[condition.field] ?? condition.field;
    final op = operatorNames[condition.operator] ?? condition.operator.name;
    final value = condition.value is List
        ? (condition.value as List).join(', ')
        : condition.value.toString();

    return '$field $op $value';
  }

  static String _formatAction(RuleAction action) {
    final actionNames = {
      ActionType.log: '记录日志',
      ActionType.notify: '发送通知',
      ActionType.stopCapture: '停止抓包',
      ActionType.startCapture: '开始抓包',
      ActionType.exportData: '导出数据',
      ActionType.executeScript: '执行脚本',
      ActionType.sendWebhook: '发送 Webhook',
      ActionType.custom: '自定义动作',
    };

    final name = actionNames[action.type] ?? action.type.name;

    if (action.type == ActionType.executeScript) {
      final scriptPath = action.config['scriptPath'] ?? '未知';
      return '$name: $scriptPath';
    }

    if (action.type == ActionType.sendWebhook) {
      final url = action.config['url'] ?? '未知';
      return '$name: $url';
    }

    return name;
  }
}

/// 规则模板
class RuleTemplates {
  static List<VisualRule> getTemplates() {
    return [
      // 模板 1: 慢请求告警
      VisualRule(
        id: 'template_slow_request',
        name: '慢请求告警',
        description: '当响应时间超过 2 秒时记录日志并发送通知',
        conditions: [
          RuleCondition(
            id: 'c1',
            type: ConditionType.httpRequest,
            field: 'responseTime',
            operator: OperatorType.greaterThan,
            value: 2000,
          ),
        ],
        actions: [
          RuleAction(
            id: 'a1',
            type: ActionType.log,
            config: {'level': 'warning', 'message': '慢请求 detected'},
          ),
          RuleAction(
            id: 'a2',
            type: ActionType.notify,
            config: {'title': '慢请求告警', 'body': '响应时间超过 2 秒'},
          ),
        ],
      ),

      // 模板 2: 错误请求监控
      VisualRule(
        id: 'template_error_request',
        name: '错误请求监控',
        description: '当状态码为 4xx 或 5xx 时记录',
        conditions: [
          RuleCondition(
            id: 'c1',
            type: ConditionType.httpRequest,
            field: 'statusCode',
            operator: OperatorType.greaterThan,
            value: 399,
          ),
        ],
        actions: [
          RuleAction(
            id: 'a1',
            type: ActionType.log,
            config: {'level': 'error', 'message': 'HTTP 错误请求'},
          ),
        ],
      ),

      // 模板 3: API 导出
      VisualRule(
        id: 'template_api_export',
        name: 'API 数据导出',
        description: '当访问特定 API 时自动导出数据',
        conditions: [
          RuleCondition(
            id: 'c1',
            type: ConditionType.httpRequest,
            field: 'path',
            operator: OperatorType.contains,
            value: '/api/',
          ),
        ],
        actions: [
          RuleAction(
            id: 'a1',
            type: ActionType.exportData,
            config: {'format': 'har', 'autoSave': true},
          ),
        ],
      ),
    ];
  }
}
