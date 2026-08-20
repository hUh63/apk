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
    // TODO: 从存储加载规则
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
    // TODO: 实现规则编辑对话框
  }

  void _duplicateRule(Rule rule) {
    // TODO: 实现规则复制
  }

  void _deleteRule(Rule rule) {
    // TODO: 实现规则删除
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
    // TODO: 实现条件编辑
  }

  void _removeCondition(int index) {
    setState(() => _conditions.removeAt(index));
  }

  void _addAction() {
    setState(() => _actions.add({'name': '新动作', 'type': 'modify_request'}));
  }

  void _editAction(int index) {
    // TODO: 实现动作编辑
  }

  void _removeAction(int index) {
    setState(() => _actions.removeAt(index));
  }

  void _saveRule() {
    // TODO: 保存规则到引擎
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
