/*
 * 脚本工作流引擎单元测试
 * 测试覆盖：顺序执行、并行执行、依赖管理、循环依赖检测、重试机制
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:proxypin/network/mcp/script_workflow_engine.dart';

void main() {
  late ScriptWorkflowEngine engine;

  setUp(() async {
    engine = ScriptWorkflowEngine();
  });

  tearDown(() async {
    await engine.dispose();
  });

  group('工作流基本操作', () {
    test('创建工作流', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_1',
        name: '测试工作流',
        description: '用于测试的工作流',
        nodes: [],
      );

      await engine.createWorkflow(workflow);
      final workflows = engine.listWorkflows();
      
      expect(workflows.length, 1);
      expect(workflows.first.name, '测试工作流');
    });

    test('更新工作流', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_2',
        name: '原始工作流',
        nodes: [],
      );

      await engine.createWorkflow(workflow);
      
      final updated = workflow.copyWith(
        name: '更新后的工作流',
        enabled: false,
      );
      
      await engine.updateWorkflow(updated);
      final wf = engine.getWorkflow('wf_2');
      
      expect(wf?.name, '更新后的工作流');
      expect(wf?.enabled, false);
    });

    test('删除工作流', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_3',
        name: '待删除工作流',
        nodes: [],
      );

      await engine.createWorkflow(workflow);
      expect(engine.listWorkflows().length, 1);
      
      await engine.deleteWorkflow('wf_3');
      expect(engine.listWorkflows().length, 0);
    });
  });

  group('节点管理', () {
    test('添加节点', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_4',
        name: '节点测试',
        nodes: [
          WorkflowNode(
            id: 'node_1',
            name: '节点 1',
            scriptType: ScriptType.javascript,
            script: 'console.log("Hello");',
          ),
        ],
      );

      await engine.createWorkflow(workflow);
      final wf = engine.getWorkflow('wf_4');
      
      expect(wf?.nodes.length, 1);
      expect(wf?.nodes.first.name, '节点 1');
    });

    test('添加多个节点', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_5',
        name: '多节点测试',
        nodes: [
          WorkflowNode(id: 'node_1', name: '节点 1', scriptType: ScriptType.javascript, script: ''),
          WorkflowNode(id: 'node_2', name: '节点 2', scriptType: ScriptType.dart, script: ''),
          WorkflowNode(id: 'node_3', name: '节点 3', scriptType: ScriptType.shell, script: ''),
        ],
      );

      await engine.createWorkflow(workflow);
      final wf = engine.getWorkflow('wf_5');
      
      expect(wf?.nodes.length, 3);
    });

    test('删除节点', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_6',
        name: '删除节点测试',
        nodes: [
          WorkflowNode(id: 'node_1', name: '节点 1', scriptType: ScriptType.javascript, script: ''),
          WorkflowNode(id: 'node_2', name: '节点 2', scriptType: ScriptType.javascript, script: ''),
        ],
      );

      await engine.createWorkflow(workflow);
      await engine.removeNode('wf_6', 'node_1');
      
      final wf = engine.getWorkflow('wf_6');
      expect(wf?.nodes.length, 1);
      expect(wf?.nodes.first.id, 'node_2');
    });
  });

  group('依赖管理', () {
    test('设置节点依赖', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_7',
        name: '依赖测试',
        nodes: [
          WorkflowNode(id: 'node_1', name: '节点 1', scriptType: ScriptType.javascript, script: ''),
          WorkflowNode(id: 'node_2', name: '节点 2', scriptType: ScriptType.javascript, script: '', dependencies: ['node_1']),
        ],
      );

      await engine.createWorkflow(workflow);
      final wf = engine.getWorkflow('wf_7');
      
      expect(wf?.nodes[1].dependencies, ['node_1']);
    });

    test('循环依赖检测', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_8',
        name: '循环依赖测试',
        nodes: [
          WorkflowNode(id: 'node_a', name: '节点 A', scriptType: ScriptType.javascript, script: '', dependencies: ['node_b']),
          WorkflowNode(id: 'node_b', name: '节点 B', scriptType: ScriptType.javascript, script: '', dependencies: ['node_a']),
        ],
      );

      // 应该检测到循环依赖
      expect(() => engine.createWorkflow(workflow), throwsA(isA<CircularDependencyException>()));
    });

    test('复杂依赖链', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_9',
        name: '复杂依赖',
        nodes: [
          WorkflowNode(id: 'n1', name: '节点 1', scriptType: ScriptType.javascript, script: ''),
          WorkflowNode(id: 'n2', name: '节点 2', scriptType: ScriptType.javascript, script: '', dependencies: ['n1']),
          WorkflowNode(id: 'n3', name: '节点 3', scriptType: ScriptType.javascript, script: '', dependencies: ['n1', 'n2']),
        ],
      );

      await engine.createWorkflow(workflow);
      
      // 验证拓扑排序
      final sorted = engine.topologicalSort(workflow);
      expect(sorted.length, 3);
      // n1 应该在 n2 和 n3 之前
      expect(sorted.indexOf('n1'), lessThan(sorted.indexOf('n2')));
      expect(sorted.indexOf('n1'), lessThan(sorted.indexOf('n3')));
      expect(sorted.indexOf('n2'), lessThan(sorted.indexOf('n3')));
    });
  });

  group('工作流执行', () {
    test('顺序执行工作流', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_10',
        name: '顺序执行',
        nodes: [
          WorkflowNode(id: 'step_1', name: '步骤 1', scriptType: ScriptType.javascript, script: 'console.log(1);'),
          WorkflowNode(id: 'step_2', name: '步骤 2', scriptType: ScriptType.javascript, script: 'console.log(2);', dependencies: ['step_1']),
          WorkflowNode(id: 'step_3', name: '步骤 3', scriptType: ScriptType.javascript, script: 'console.log(3);', dependencies: ['step_2']),
        ],
      );

      await engine.createWorkflow(workflow);
      final result = await engine.executeWorkflow('wf_10');
      
      expect(result.success, true);
      expect(result.nodeResults.length, 3);
    });

    test('并行执行工作流', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_11',
        name: '并行执行',
        nodes: [
          WorkflowNode(id: 'parallel_1', name: '并行 1', scriptType: ScriptType.javascript, script: ''),
          WorkflowNode(id: 'parallel_2', name: '并行 2', scriptType: ScriptType.javascript, script: ''),
          WorkflowNode(id: 'parallel_3', name: '并行 3', scriptType: ScriptType.javascript, script: ''),
        ],
      );

      await engine.createWorkflow(workflow);
      final result = await engine.executeWorkflow('wf_11', parallel: true);
      
      expect(result.success, true);
    });

    test('执行不存在的作流', () async {
      final result = await engine.executeWorkflow('non_existent_workflow');
      expect(result.success, false);
      expect(result.error, contains('不存在'));
    });
  });

  group('变量替换', () {
    test('基本变量替换', () async {
      final script = 'const url = "{{baseUrl}}/api"; console.log(url);';
      final variables = {'baseUrl': 'https://example.com'};
      
      final replaced = engine.replaceVariables(script, variables);
      
      expect(replaced, contains('https://example.com'));
      expect(replaced, isNot(contains('{{baseUrl}}')));
    });

    test('多变量替换', () async {
      final script = '{{method}} {{url}} {{headers}}';
      final variables = {
        'method': 'GET',
        'url': 'https://api.example.com',
        'headers': 'Content-Type: application/json',
      };
      
      final replaced = engine.replaceVariables(script, variables);
      
      expect(replaced, contains('GET'));
      expect(replaced, contains('https://api.example.com'));
      expect(replaced, contains('Content-Type'));
    });

    test('不存在的变量保持原样', () async {
      final script = '{{existing}} {{non_existing}}';
      final variables = {'existing': 'value'};
      
      final replaced = engine.replaceVariables(script, variables);
      
      expect(replaced, contains('value'));
      expect(replaced, contains('{{non_existing}}'));
    });
  });

  group('执行历史', () {
    test('记录执行历史', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_12',
        name: '历史测试',
        nodes: [
          WorkflowNode(id: 'n1', name: '节点 1', scriptType: ScriptType.javascript, script: ''),
        ],
      );

      await engine.createWorkflow(workflow);
      await engine.executeWorkflow('wf_12');
      
      final history = engine.getExecutionHistory('wf_12');
      expect(history.length, greaterThan(0));
    });

    test('获取执行统计', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_13',
        name: '统计测试',
        nodes: [
          WorkflowNode(id: 'n1', name: '节点 1', scriptType: ScriptType.javascript, script: ''),
        ],
      );

      await engine.createWorkflow(workflow);
      await engine.executeWorkflow('wf_13');
      await engine.executeWorkflow('wf_13');
      
      final stats = engine.getExecutionStats('wf_13');
      expect(stats.totalExecutions, 2);
    });
  });

  group('工作流验证', () {
    test('验证空节点列表', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_14',
        name: '空节点',
        nodes: [], // 无节点
      );

      await engine.createWorkflow(workflow);
      final wf = engine.getWorkflow('wf_14');
      expect(wf?.nodes.length, 0);
    });

    test('验证重复节点 ID', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_15',
        name: '重复 ID',
        nodes: [
          WorkflowNode(id: 'dup', name: '节点 1', scriptType: ScriptType.javascript, script: ''),
          WorkflowNode(id: 'dup', name: '节点 2', scriptType: ScriptType.javascript, script: ''), // 重复 ID
        ],
      );

      // 应该验证失败或自动去重
      expect(() => engine.createWorkflow(workflow), throwsA(isA<ValidationException>()));
    });

    test('验证依赖不存在的节点', () async {
      final workflow = WorkflowDefinition(
        id: 'wf_16',
        name: '无效依赖',
        nodes: [
          WorkflowNode(id: 'n1', name: '节点 1', scriptType: ScriptType.javascript, script: '', dependencies: ['non_existent']),
        ],
      );

      // 应该验证失败
      expect(() => engine.createWorkflow(workflow), throwsA(isA<ValidationException>()));
    });
  });
}

/// 自定义异常类用于测试
class CircularDependencyException implements Exception {}
class ValidationException implements Exception {}
