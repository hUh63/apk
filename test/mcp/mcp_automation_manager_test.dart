/*
 * MCP 自动化任务管理器单元测试
 * 测试覆盖：CRUD 操作、持久化存储、任务调度
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:proxypin/network/mcp/mcp_automation_manager.dart';
import 'package:proxypin/network/mcp/mcp_scheduler.dart';

void main() {
  late McpAutomationManager manager;

  setUp(() async {
    manager = McpAutomationManager();
    await manager.initialize();
  });

  tearDown(() async {
    await manager.dispose();
  });

  group('MCP 自动化任务 CRUD 操作', () {
    test('创建任务', () async {
      final task = MCPAutomationTask(
        id: 'test_task_1',
        name: '测试任务',
        enabled: true,
        trigger: TriggerConfig(
          type: TriggerType.cron,
          cronExpression: '0 */5 * * * ?', // 每 5 分钟
        ),
        actions: [
          ActionConfig(
            type: ActionType.log,
            params: {'message': 'Hello World'},
          ),
        ],
      );

      await manager.addTask(task);
      final tasks = manager.getTasks();
      
      expect(tasks.length, 1);
      expect(tasks.first.name, '测试任务');
      expect(tasks.first.enabled, true);
    });

    test('更新任务', () async {
      final task = MCPAutomationTask(
        id: 'test_task_2',
        name: '原始任务',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [],
      );

      await manager.addTask(task);
      
      // 更新任务
      final updatedTask = task.copyWith(
        name: '更新后的任务',
        enabled: false,
      );
      
      await manager.updateTask(updatedTask);
      final tasks = manager.getTasks();
      
      expect(tasks.first.name, '更新后的任务');
      expect(tasks.first.enabled, false);
    });

    test('删除任务', () async {
      final task = MCPAutomationTask(
        id: 'test_task_3',
        name: '待删除任务',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [],
      );

      await manager.addTask(task);
      expect(manager.getTasks().length, 1);
      
      await manager.deleteTask('test_task_3');
      expect(manager.getTasks().length, 0);
    });

    test('启用/禁用任务', () async {
      final task = MCPAutomationTask(
        id: 'test_task_4',
        name: '开关测试',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [],
      );

      await manager.addTask(task);
      
      await manager.toggleTask('test_task_4', false);
      expect(manager.getTask('test_task_4')?.enabled, false);
      
      await manager.toggleTask('test_task_4', true);
      expect(manager.getTask('test_task_4')?.enabled, true);
    });
  });

  group('触发器配置测试', () {
    test('Cron 触发器', () async {
      final task = MCPAutomationTask(
        id: 'cron_task',
        name: 'Cron 任务',
        enabled: true,
        trigger: TriggerConfig(
          type: TriggerType.cron,
          cronExpression: '0 0 12 * * ?', // 每天 12 点
        ),
        actions: [],
      );

      await manager.addTask(task);
      expect(task.trigger.type, TriggerType.cron);
      expect(task.trigger.cronExpression, '0 0 12 * * ?');
    });

    test('事件触发器', () async {
      final task = MCPAutomationTask(
        id: 'event_task',
        name: '事件任务',
        enabled: true,
        trigger: TriggerConfig(
          type: TriggerType.event,
          eventName: 'proxy.started',
        ),
        actions: [],
      );

      await manager.addTask(task);
      expect(task.trigger.type, TriggerType.event);
      expect(task.trigger.eventName, 'proxy.started');
    });

    test('请求规则触发器', () async {
      final task = MCPAutomationTask(
        id: 'request_task',
        name: '请求任务',
        enabled: true,
        trigger: TriggerConfig(
          type: TriggerType.requestRule,
          ruleId: 'rule_123',
        ),
        actions: [],
      );

      await manager.addTask(task);
      expect(task.trigger.type, TriggerType.requestRule);
      expect(task.trigger.ruleId, 'rule_123');
    });
  });

  group('动作配置测试', () {
    test('修改请求动作', () async {
      final task = MCPAutomationTask(
        id: 'modify_req_task',
        name: '修改请求',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [
          ActionConfig(
            type: ActionType.modifyRequest,
            params: {
              'headers': {'X-Custom-Header': 'value'},
              'body': '{"test": true}',
            },
          ),
        ],
      );

      await manager.addTask(task);
      expect(task.actions.length, 1);
      expect(task.actions.first.type, ActionType.modifyRequest);
    });

    test('执行脚本动作', () async {
      final task = MCPAutomationTask(
        id: 'script_task',
        name: '执行脚本',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [
          ActionConfig(
            type: ActionType.runScript,
            params: {
              'language': 'javascript',
              'script': 'console.log("Hello");',
            },
          ),
        ],
      );

      await manager.addTask(task);
      expect(task.actions.first.type, ActionType.runScript);
      expect(task.actions.first.params['language'], 'javascript');
    });

    test('导出数据的', () async {
      final task = MCPAutomationTask(
        id: 'export_task',
        name: '导出数据',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [
          ActionConfig(
            type: ActionType.exportData,
            params: {
              'format': 'har',
              'path': '/sdcard/export.har',
            },
          ),
        ],
      );

      await manager.addTask(task);
      expect(task.actions.first.type, ActionType.exportData);
      expect(task.actions.first.params['format'], 'har');
    });
  });

  group('任务执行测试', () {
    test('执行单个任务', () async {
      final task = MCPAutomationTask(
        id: 'execute_task',
        name: '执行测试',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [
          ActionConfig(type: ActionType.log, params: {'message': 'Test'}),
        ],
      );

      await manager.addTask(task);
      
      // 手动执行任务
      final result = await manager.executeTask('execute_task');
      expect(result.success, true);
    });

    test('执行不存在的任务', () async {
      final result = await manager.executeTask('non_existent_task');
      expect(result.success, false);
      expect(result.error, contains('不存在'));
    });
  });

  group('任务验证', () {
    test('任务 ID 唯一性', () async {
      final task1 = MCPAutomationTask(
        id: 'unique_task',
        name: '任务 1',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [],
      );

      final task2 = MCPAutomationTask(
        id: 'unique_task', // 重复 ID
        name: '任务 2',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [],
      );

      await manager.addTask(task1);
      
      // 添加重复 ID 的任务应该失败或覆盖
      await manager.addTask(task2);
      final tasks = manager.getTasks();
      
      // 验证只有一个任务
      expect(tasks.length, 1);
      expect(tasks.first.name, '任务 2'); // 应该是更新后的
    });

    test('空动作列表任务', () async {
      final task = MCPAutomationTask(
        id: 'empty_actions_task',
        name: '空动作任务',
        enabled: true,
        trigger: TriggerConfig(type: TriggerType.cron, cronExpression: '0 0 * * * ?'),
        actions: [], // 无动作
      );

      await manager.addTask(task);
      final tasks = manager.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.actions.length, 0);
    });
  });
}
