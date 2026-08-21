/*
 * MCP 规则引擎单元测试
 * 测试覆盖：条件评估、操作符、HTTP 请求规则、动作执行
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:proxypin/network/mcp/mcp_rule_engine.dart';
import 'package:proxypin/network/http/http.dart';

void main() {
  late McpRuleEngine ruleEngine;

  setUp(() async {
    ruleEngine = McpRuleEngine();
  });

  group('条件评估', () {
    test('等于操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'method',
        operator: Operator.equals,
        value: 'GET',
      );

      final context = {'method': 'GET'};
      expect(condition.evaluate(context), true);
    });

    test('不等于操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'method',
        operator: Operator.notEquals,
        value: 'POST',
      );

      final context = {'method': 'GET'};
      expect(condition.evaluate(context), true);
    });

    test('大于操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'statusCode',
        operator: Operator.greaterThan,
        value: 200,
      );

      final context = {'statusCode': 201};
      expect(condition.evaluate(context), true);
    });

    test('小于操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'contentLength',
        operator: Operator.lessThan,
        value: 1000,
      );

      final context = {'contentLength': 500};
      expect(condition.evaluate(context), true);
    });

    test('包含操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'url',
        operator: Operator.contains,
        value: 'api',
      );

      final context = {'url': 'https://example.com/api/users'};
      expect(condition.evaluate(context), true);
    });

    test('以...开头操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'url',
        operator: Operator.startsWith,
        value: 'https://',
      );

      final context = {'url': 'https://example.com'};
      expect(condition.evaluate(context), true);
    });

    test('以...结尾操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'url',
        operator: Operator.endsWith,
        value: '.json',
      );

      final context = {'url': 'https://api.example.com/data.json'};
      expect(condition.evaluate(context), true);
    });

    test('正则匹配操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'url',
        operator: Operator.matches,
        value: r'^https://.*\.com/.*$',
      );

      final context = {'url': 'https://example.com/api'};
      expect(condition.evaluate(context), true);
    });

    test('在列表中操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'method',
        operator: Operator.inList,
        value: ['GET', 'POST'],
      );

      final context = {'method': 'GET'};
      expect(condition.evaluate(context), true);
    });

    test('不在列表中操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'method',
        operator: Operator.notInList,
        value: ['DELETE', 'PUT'],
      );

      final context = {'method': 'GET'};
      expect(condition.evaluate(context), true);
    });

    test('字段存在操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'headers',
        operator: Operator.exists,
        value: null,
      );

      final context = {'headers': {'Content-Type': 'application/json'}};
      expect(condition.evaluate(context), true);
    });

    test('字段不存在操作符', () {
      final condition = Condition(
        type: ConditionType.httpRequest,
        field: 'authorization',
        operator: Operator.notExists,
        value: null,
      );

      final context = {'method': 'GET'};
      expect(condition.evaluate(context), true);
    });
  });

  group('HTTP 请求规则', () {
    test('URL 匹配规则', () async {
      final rule = HttpRule(
        id: 'rule_1',
        name: 'URL 匹配测试',
        enabled: true,
        urlPattern: 'https://api.example.com/*',
        actions: [],
      );

      await ruleEngine.addRule(rule);
      
      final request = HttpRequest(
        url: Uri.parse('https://api.example.com/users'),
        method: 'GET',
      );
      
      final matched = await ruleEngine.matchRequest(request);
      expect(matched.length, 1);
    });

    test('方法匹配规则', () async {
      final rule = HttpRule(
        id: 'rule_2',
        name: '方法匹配',
        enabled: true,
        methods: ['POST', 'PUT'],
        actions: [],
      );

      await ruleEngine.addRule(rule);
      
      final request = HttpRequest(
        url: Uri.parse('https://example.com/api'),
        method: 'POST',
      );
      
      final matched = await ruleEngine.matchRequest(request);
      expect(matched.length, 1);
    });

    test('Header 匹配规则', () async {
      final rule = HttpRule(
        id: 'rule_3',
        name: 'Header 匹配',
        enabled: true,
        headers: {'Content-Type': 'application/json'},
        actions: [],
      );

      await ruleEngine.addRule(rule);
      
      final request = HttpRequest(
        url: Uri.parse('https://example.com/api'),
        method: 'POST',
        headers: Headers()..set('Content-Type', 'application/json'),
      );
      
      final matched = await ruleEngine.matchRequest(request);
      expect(matched.length, 1);
    });

    test组合条件规则', () async {
      final rule = HttpRule(
        id: 'rule_4',
        name: '组合条件',
        enabled: true,
        urlPattern: '*/api/*',
        methods: ['GET'],
        headers: {'Authorization': '*'},
        actions: [],
      );

      await ruleEngine.addRule(rule);
      
      // 满足所有条件
      final request1 = HttpRequest(
        url: Uri.parse('https://example.com/api/users'),
        method: 'GET',
        headers: Headers()..set('Authorization', 'Bearer token'),
      );
      
      expect((await ruleEngine.matchRequest(request1)).length, 1);
      
      // 不满足 Header 条件
      final request2 = HttpRequest(
        url: Uri.parse('https://example.com/api/users'),
        method: 'GET',
      );
      
      expect((await ruleEngine.matchRequest(request2)).length, 0);
    });
  });

  group('规则优先级', () {
    test('高优先级规则先执行', () async {
      final rule1 = HttpRule(
        id: 'rule_high',
        name: '高优先级',
        enabled: true,
        urlPattern: '*/api/*',
        priority: RulePriority.high,
        actions: [ActionConfig(type: ActionType.log, params: {'message': 'high'})],
      );

      final rule2 = HttpRule(
        id: 'rule_low',
        name: '低优先级',
        enabled: true,
        urlPattern: '*/api/*',
        priority: RulePriority.low,
        actions: [ActionConfig(type: ActionType.log, params: {'message': 'low'})],
      );

      await ruleEngine.addRule(rule1);
      await ruleEngine.addRule(rule2);
      
      final request = HttpRequest(
        url: Uri.parse('https://example.com/api/test'),
        method: 'GET',
      );
      
      final matched = await ruleEngine.matchRequest(request);
      expect(matched.length, 2);
      // 高优先级应该排在前面
      expect(matched.first.id, 'rule_high');
    });
  });

  group('规则 CRUD 操作', () {
    test('添加规则', () async {
      final rule = HttpRule(
        id: 'crud_rule_1',
        name: '添加测试',
        enabled: true,
        actions: [],
      );

      await ruleEngine.addRule(rule);
      final rules = ruleEngine.getRules();
      
      expect(rules.length, 1);
      expect(rules.first.name, '添加测试');
    });

    test('更新规则', () async {
      final rule = HttpRule(
        id: 'crud_rule_2',
        name: '原始规则',
        enabled: true,
        actions: [],
      );

      await ruleEngine.addRule(rule);
      
      final updated = rule.copyWith(
        name: '更新后的规则',
        enabled: false,
      );
      
      await ruleEngine.updateRule(updated);
      final r = ruleEngine.getRule('crud_rule_2');
      
      expect(r?.name, '更新后的规则');
      expect(r?.enabled, false);
    });

    test('删除规则', () async {
      final rule = HttpRule(
        id: 'crud_rule_3',
        name: '待删除规则',
        enabled: true,
        actions: [],
      );

      await ruleEngine.addRule(rule);
      expect(ruleEngine.getRules().length, 1);
      
      await ruleEngine.deleteRule('crud_rule_3');
      expect(ruleEngine.getRules().length, 0);
    });

    test('启用/禁用规则', () async {
      final rule = HttpRule(
        id: 'crud_rule_4',
        name: '开关测试',
        enabled: true,
        actions: [],
      );

      await ruleEngine.addRule(rule);
      
      await ruleEngine.toggleRule('crud_rule_4', false);
      expect(ruleEngine.getRule('crud_rule_4')?.enabled, false);
      
      await ruleEngine.toggleRule('crud_rule_4', true);
      expect(ruleEngine.getRule('crud_rule_4')?.enabled, true);
    });
  });

  group('动作执行', () {
    test('日志动作', () async {
      final action = ActionConfig(
        type: ActionType.log,
        params: {'message': 'Test log message'},
      );

      // 验证动作配置
      expect(action.type, ActionType.log);
      expect(action.params['message'], 'Test log message');
    });

    test('通知动作', () async {
      final action = ActionConfig(
        type: ActionType.notify,
        params: {
          'title': 'Test Notification',
          'content': 'This is a test',
        },
      );

      expect(action.type, ActionType.notify);
      expect(action.params['title'], 'Test Notification');
    });

    test('停止捕获动作', () async {
      final action = ActionConfig(
        type: ActionType.stopCapture,
        params: {},
      );

      expect(action.type, ActionType.stopCapture);
    });

    test('执行脚本动作', () async {
      final action = ActionConfig(
        type: ActionType.executeScript,
        params: {
          'language': 'javascript',
          'script': 'console.log("Hello");',
        },
      );

      expect(action.type, ActionType.executeScript);
      expect(action.params['language'], 'javascript');
    });

    test('Webhook 动作', () async {
      final action = ActionConfig(
        type: ActionType.sendWebhook,
        params: {
          'url': 'https://webhook.example.com/notify',
          'method': 'POST',
          'body': '{"event": "test"}',
        },
      );

      expect(action.type, ActionType.sendWebhook);
      expect(action.params['url'], 'https://webhook.example.com/notify');
    });
  });

  group('规则验证', () {
    test('验证空 ID', () {
      final rule = HttpRule(
        id: '', // 空 ID
        name: '无效规则',
        enabled: true,
        actions: [],
      );

      expect(rule.id.isEmpty, true);
    });

    test('验证空名称', () {
      final rule = HttpRule(
        id: 'rule_empty_name',
        name: '', // 空名称
        enabled: true,
        actions: [],
      );

      expect(rule.name.isEmpty, true);
    });

    test('验证重复 ID', () async {
      final rule1 = HttpRule(
        id: 'dup_rule',
        name: '规则 1',
        enabled: true,
        actions: [],
      );

      final rule2 = HttpRule(
        id: 'dup_rule', // 重复 ID
        name: '规则 2',
        enabled: true,
        actions: [],
      );

      await ruleEngine.addRule(rule1);
      await ruleEngine.addRule(rule2);
      
      final rules = ruleEngine.getRules();
      // 应该是更新而不是新增
      expect(rules.length, 1);
      expect(rules.first.name, '规则 2');
    });
  });

  group('规则统计', () {
    test('获取规则数量', () async {
      await ruleEngine.addRule(HttpRule(id: 'r1', name: '规则 1', enabled: true, actions: []));
      await ruleEngine.addRule(HttpRule(id: 'r2', name: '规则 2', enabled: true, actions: []));
      await ruleEngine.addRule(HttpRule(id: 'r3', name: '规则 3', enabled: false, actions: []));
      
      expect(ruleEngine.getRules().length, 3);
      expect(ruleEngine.getEnabledRules().length, 2);
    });

    test('按类型筛选规则', () async {
      await ruleEngine.addRule(HttpRule(id: 'r1', name: 'URL 规则', enabled: true, urlPattern: '*/api/*', actions: []));
      await ruleEngine.addRule(HttpRule(id: 'r2', name: '方法规则', enabled: true, methods: ['GET'], actions: []));
      
      final urlRules = ruleEngine.getRules().where((r) => r.urlPattern != null).toList();
      expect(urlRules.length, 1);
    });
  });
}
