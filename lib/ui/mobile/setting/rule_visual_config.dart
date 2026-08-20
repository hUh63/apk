import 'package:flutter/material.dart';
import '../../../network/mcp/mcp_rule_engine.dart';

/// 规则可视化配置页面
/// 提供图形化界面用于创建、编辑和管理 MCP 规则
/// @author wanghongen
/// 2026-08-20
class RuleVisualConfig extends StatefulWidget {
  const RuleVisualConfig({super.key});

  @override
  State<RuleVisualConfig> createState() => _RuleVisualConfigState();
}

class _RuleVisualConfigState extends State<RuleVisualConfig> {
  final McpRuleEngine _ruleEngine = McpRuleEngine();
  final List<Rule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    // 从规则引擎加载规则列表
    _rules.clear();
    _rules.addAll(_ruleEngine.rules);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('规则可视化配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateRuleDialog,
            tooltip: '创建规则',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRules,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? _buildEmptyState()
              : _buildRuleList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRuleDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rule_folder, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无规则',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 创建第一个规则',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleList() {
    return ListView.builder(
      cacheExtent: 300,
      itemCount: _rules.length,
      itemBuilder: (context, index) {
        final rule = _rules[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(
              rule.enabled ? Icons.check_circle : Icons.cancel,
              color: rule.enabled ? Colors.green : Colors.grey,
            ),
            title: Text(rule.name ?? '未命名规则'),
            subtitle: Text('条件：${rule.conditions.length} | 动作：${rule.actions.length}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleRuleAction(value, rule),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'toggle', child: Text('启用/禁用')),
                const PopupMenuItem(value: 'duplicate', child: Text('复制')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _showCreateRuleDialog() {
    showDialog(
      context: context,
      builder: (context) => _RuleEditorDialog(),
    );
  }

  void _handleRuleAction(String action, Rule rule) {
    switch (action) {
      case 'edit':
        _showEditRuleDialog(rule);
        break;
      case 'toggle':
        setState(() => rule.enabled = !rule.enabled);
        break;
      case 'duplicate':
        _duplicateRule(rule);
        break;
      case 'delete':
        _deleteRule(rule);
        break;
    }
  }

  void _showEditRuleDialog(Rule rule) {
    showDialog(
      context: context,
      builder: (context) => _RuleEditorDialog(rule: rule),
    ).then((_) => _loadRules());
  }

  void _duplicateRule(Rule rule) {
    final newRule = rule.copyWith(name: '${rule.name ?? '规则'} (副本)');
    setState(() => _rules.add(newRule));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制规则：${newRule.name}')),
    );
  }

  void _deleteRule(Rule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定要删除规则「${rule.name ?? '未命名'}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _rules.remove(rule));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除规则：${rule.name ?? '未命名'}')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 规则编辑对话框
class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog();

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<Map<String, dynamic>> _conditions = [];
  final List<Map<String, dynamic>> _actions = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建/编辑规则'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 规则名称
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '规则名称',
                hintText: '例如：拦截广告请求',
              ),
            ),
            const SizedBox(height: 16),
            // 规则描述
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '规则描述',
                hintText: '简要描述规则用途',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            // 条件配置区域
            _buildSection(
              title: '触发条件',
              icon: Icons.filter_list,
              items: _conditions,
              onAdd: _addCondition,
              onEdit: _editCondition,
              onDelete: _removeCondition,
            ),
            const SizedBox(height: 16),
            // 动作配置区域
            _buildSection(
              title: '执行动作',
              icon: Icons.bolt,
              items: _actions,
              onAdd: _addAction,
              onEdit: _editAction,
              onDelete: _removeAction,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveRule,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required VoidCallback onAdd,
    required Function(int) onEdit,
    required Function(int) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle, size: 20),
              onPressed: onAdd,
              tooltip: '添加${title}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '暂无${title}',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          )
        else
          ...items.asMap().entries.map((entry) => _buildConditionOrActionItem(
                index: entry.key,
                item: entry.value,
                onEdit: onEdit,
                onDelete: onDelete,
              )),
      ],
    );
  }

  Widget _buildConditionOrActionItem({
    required int index,
    required Map<String, dynamic> item,
    required Function(int) onEdit,
    required Function(int) onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(item['name'] ?? '未命名'),
        subtitle: Text(item['description'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => onEdit(index),
              tooltip: '编辑',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => onDelete(index),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  void _addCondition() {
    setState(() => _conditions.add({'name': '新条件', 'type': 'url_pattern'}));
  }

  void _editCondition(int index) {
    // 打开条件编辑器（预填当前值）
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑条件'),
        content: TextField(
          decoration: const InputDecoration(labelText: '条件名称'),
          initialValue: _conditions[index]['name'] as String?,
          onChanged: (v) => _conditions[index]['name'] = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(onPressed: () { setState(() {}); Navigator.pop(context); }, child: const Text('保存')),
        ],
      ),
    );
  }

  void _removeCondition(int index) {
    setState(() => _conditions.removeAt(index));
  }

  void _addAction() {
    setState(() => _actions.add({'name': '新动作', 'type': 'modify_request'}));
  }

  void _editAction(int index) {
    // 打开动作编辑器（预填当前值）
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑动作'),
        content: TextField(
          decoration: const InputDecoration(labelText: '动作名称'),
          initialValue: _actions[index]['name'] as String?,
          onChanged: (v) => _actions[index]['name'] = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(onPressed: () { setState(() {}); Navigator.pop(context); }, child: const Text('保存')),
        ],
      ),
    );
  }

  void _removeAction(int index) {
    setState(() => _actions.removeAt(index));
  }

  void _saveRule() {
    // 保存规则到规则引擎
    final rule = Rule(
      name: _nameController.text.trim().isEmpty ? '未命名规则' : _nameController.text.trim(),
      enabled: true,
      conditions: _conditions,
      actions: _actions,
    );
    McpRuleEngine().addRule(rule);
    Navigator.pop(context, rule);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
