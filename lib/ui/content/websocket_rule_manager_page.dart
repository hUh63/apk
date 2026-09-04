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

import 'package:flutter/material.dart';
import 'package:proxypin/network/rules/websocket_rule.dart';
import 'package:proxypin/network/rules/websocket_rule_manager.dart';
import '../../l10n/app_localizations.dart';

/// WebSocket 规则管理界面
class WebSocketRuleManagerPage extends StatefulWidget {
  const WebSocketRuleManagerPage({super.key});

  @override
  State<WebSocketRuleManagerPage> createState() => _WebSocketRuleManagerPageState();
}

class _WebSocketRuleManagerPageState extends State<WebSocketRuleManagerPage> {
  final WebSocketRuleManager _ruleManager = WebSocketRuleManager();
  List<WebSocketRule> _rules = [];
  bool _isLoading = true;
  bool _globalEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    
    // 确保初始化
    await _ruleManager.init();
    
    setState(() {
      _rules = _ruleManager.rules;
      _globalEnabled = _ruleManager.globalEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleGlobalEnabled(bool value) async {
    await _ruleManager.setGlobalEnabled(value);
    setState(() => _globalEnabled = value);
  }

  Future<void> _deleteRule(WebSocketRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除规则'),
        content: Text('确定要删除规则 "${rule.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _ruleManager.deleteRule(rule.id);
      await _loadRules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('规则已删除')),
        );
      }
    }
  }

  Future<void> _toggleRule(WebSocketRule rule) async {
    await _ruleManager.toggleRule(rule.id);
    await _loadRules();
  }

  Future<void> _editRule(WebSocketRule rule) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RuleEditDialog(rule: rule),
    );

    if (result != null) {
      final updated = rule.copyWith(
        name: result['name'] as String,
        pattern: result['pattern'] as String,
        mode: result['mode'] as RuleMatchMode,
        description: result['description'] as String?,
        interceptOutgoing: result['interceptOutgoing'] as bool,
        interceptIncoming: result['interceptIncoming'] as bool,
      );
      await _ruleManager.updateRule(rule.id, updated);
      await _loadRules();
    }
  }

  Future<void> _addRule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RuleEditDialog(),
    );

    if (result != null) {
      await _ruleManager.addRule(
        name: result['name'] as String,
        pattern: result['pattern'] as String,
        mode: result['mode'] as RuleMatchMode,
        description: result['description'] as String?,
        interceptOutgoing: result['interceptOutgoing'] as bool,
        interceptIncoming: result['interceptIncoming'] as bool,
      );
      await _loadRules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('规则已添加')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('WebSocket 拦截规则'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRules,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 全局开关卡片
                Card(
                  margin: EdgeInsets.all(16),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.rule,
                          size: 32,
                          color: _globalEnabled ? Colors.green : Colors.grey,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '全局拦截开关',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _globalEnabled
                                    ? '已启用 - 匹配规则的消息将被拦截'
                                    : '已禁用 - 所有消息直接放行',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _globalEnabled,
                          onChanged: _toggleGlobalEnabled,
                        ),
                      ],
                    ),
                  ),
                ),

                // 规则列表
                Expanded(
                  child: _rules.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rule_folder,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                '暂无规则',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '点击下方按钮添加规则',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _rules.length,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final rule = _rules[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(
                                  rule.enabled
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: rule.enabled ? Colors.green : Colors.grey,
                                ),
                                title: Text(
                                  rule.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: rule.enabled
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Text(
                                      '${_getModeName(rule.mode)}: ${rule.pattern}',
                                      style: TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (rule.description != null &&
                                        rule.description!.isNotEmpty) ...[
                                      SizedBox(height: 2),
                                      Text(
                                        rule.description!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (rule.interceptOutgoing)
                                          Chip(
                                            label: Text('OUT',
                                                style: TextStyle(fontSize: 10)),
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        if (rule.interceptIncoming) ...[
                                          SizedBox(width: 4),
                                          Chip(
                                            label: Text('IN',
                                                style: TextStyle(fontSize: 10)),
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'toggle':
                                        _toggleRule(rule);
                                        break;
                                      case 'edit':
                                        _editRule(rule);
                                        break;
                                      case 'delete':
                                        _deleteRule(rule);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(rule.enabled ? '禁用' : '启用'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('编辑'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        '删除',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRule,
        child: Icon(Icons.add),
      ),
    );
  }

  String _getModeName(RuleMatchMode mode) {
    switch (mode) {
      case RuleMatchMode.contains:
        return '包含';
      case RuleMatchMode.startsWith:
        return '开头';
      case RuleMatchMode.endsWith:
        return '结尾';
      case RuleMatchMode.regex:
        return '正则';
      case RuleMatchMode.exact:
        return '完全匹配';
    }
  }
}

/// 规则编辑对话框
class RuleEditDialog extends StatefulWidget {
  final WebSocketRule? rule;

  const RuleEditDialog({super.key, this.rule});

  @override
  State<RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<RuleEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _patternController;
  late TextEditingController _descriptionController;
  late RuleMatchMode _mode;
  late bool _interceptOutgoing;
  late bool _interceptIncoming;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule?.name ?? '');
    _patternController = TextEditingController(text: widget.rule?.pattern ?? '');
    _descriptionController =
        TextEditingController(text: widget.rule?.description ?? '');
    _mode = widget.rule?.mode ?? RuleMatchMode.contains;
    _interceptOutgoing = widget.rule?.interceptOutgoing ?? true;
    _interceptIncoming = widget.rule?.interceptIncoming ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rule == null ? '添加规则' : '编辑规则'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '规则名称',
                  hintText: '例如：API 拦截',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入规则名称';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _patternController,
                decoration: InputDecoration(
                  labelText: '匹配模式',
                  hintText: '例如：api.example.com',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入匹配模式';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<RuleMatchMode>(
                  isExpanded: true,
                value: _mode,
                decoration: InputDecoration(labelText: '匹配方式'),
                items: [
                  DropdownMenuItem(
                    value: RuleMatchMode.contains,
                    child: Text('包含'),
                  ),
                  DropdownMenuItem(
                    value: RuleMatchMode.startsWith,
                    child: Text('开头'),
                  ),
                  DropdownMenuItem(
                    value: RuleMatchMode.endsWith,
                    child: Text('结尾'),
                  ),
                  DropdownMenuItem(
                    value: RuleMatchMode.regex,
                    child: Text('正则表达式'),
                  ),
                  DropdownMenuItem(
                    value: RuleMatchMode.exact,
                    child: Text('完全匹配'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _mode = value);
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: '规则描述 (可选)',
                  hintText: '例如：拦截所有 API 请求',
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),
              Text('拦截方向:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: Text('发出 (OUT)'),
                      value: _interceptOutgoing,
                      onChanged: (value) {
                        setState(() => _interceptOutgoing = value ?? false);
                      },
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: Text('接收 (IN)'),
                      value: _interceptIncoming,
                      onChanged: (value) {
                        setState(() => _interceptIncoming = value ?? false);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (!_interceptOutgoing && !_interceptIncoming) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请至少选择一个拦截方向')),
                );
                return;
              }
              Navigator.pop(context, {
                'name': _nameController.text,
                'pattern': _patternController.text,
                'mode': _mode,
                'description': _descriptionController.text.isEmpty
                    ? null
                    : _descriptionController.text,
                'interceptOutgoing': _interceptOutgoing,
                'interceptIncoming': _interceptIncoming,
              });
            }
          },
          child: Text('保存'),
        ),
      ],
    );
  }
}
