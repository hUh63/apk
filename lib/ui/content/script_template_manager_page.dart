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
import 'package:flutter/services.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/scripts/script_templates.dart';
import 'package:proxypin/ui/component/app_dialog.dart';
import 'package:proxypin/ui/component/code_editor.dart';
import 'package:proxypin/ui/component/utils.dart';

/// 脚本模板管理页面 (Feature 3)
/// 提供常用脚本模板的浏览、搜索和使用
class ScriptTemplateManagerPage extends StatefulWidget {
  const ScriptTemplateManagerPage({super.key});

  @override
  State<ScriptTemplateManagerPage> createState() => _ScriptTemplateManagerPageState();
}

class _ScriptTemplateManagerPageState extends State<ScriptTemplateManagerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  
  // 选中的模板 (用于预览)
  dynamic _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('脚本模板库'),
        subtitle: Text('Feature 3 - 常用脚本模板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearchDialog();
            },
            tooltip: '搜索模板',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showHelpDialog();
            },
            tooltip: '帮助',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.javascript), text: 'JavaScript'),
            Tab(icon: Icon(Icons.code), text: 'Dart'),
            Tab(icon: Icon(Icons.terminal), text: 'Shell'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索模板...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // 模板列表
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateList(ScriptLanguage.javascript),
                _buildTemplateList(ScriptLanguage.dart),
                _buildTemplateList(ScriptLanguage.shell),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(ScriptLanguage language) {
    List<dynamic> templates;
    
    switch (language) {
      case ScriptLanguage.javascript:
        templates = ScriptTemplates.getAllJSTemplates();
        break;
      case ScriptLanguage.dart:
        templates = ScriptTemplates.getAllDartTemplates();
        break;
      case ScriptLanguage.shell:
        templates = ScriptTemplates.getAllShellTemplates();
        break;
    }

    // 应用搜索过滤
    if (_searchQuery.isNotEmpty) {
      templates = templates.where((t) {
        final query = _searchQuery.toLowerCase();
        return t.name.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query) ||
            t.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的模板',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(template.category),
              child: Icon(
                _getCategoryIcon(template.category),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              template.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              template.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() {
                _selectedTemplate = template;
              });
              showTemplateDetailDialog(template);
            },
          ),
        );
      },
    );
  }

  void showTemplateDetailDialog(dynamic template) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getCategoryColor(template.category),
                    child: Icon(
                      _getCategoryIcon(template.category),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          template.description,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // 标签
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: template.tags.map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ),
            
            // 代码区域
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 代码标题
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.code, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '${template.language.displayName} 代码',
                            style: theme.textTheme.labelMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: template.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('代码已复制到剪贴板')),
                              );
                            },
                            tooltip: '复制代码',
                          ),
                        ],
                      ),
                    ),
                    
                    // 代码内容
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          template.code,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 操作按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // 打开代码编辑器并加载模板
                        showDialog(
                          context: context,
                          builder: (context) => CodeEditorDialog(
                            title: '使用模板 - ${template.name}',
                            initialCode: template.code,
                            language: template.language,
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('使用此模板'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: template.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('代码已复制')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('复制代码'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索模板'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入关键词...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: const Text('清除'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('脚本模板库'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('脚本模板库提供常用的脚本模板，帮助您快速开始编写脚本。'),
              SizedBox(height: 16),
              Text('支持的语言:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• JavaScript - 用于请求/响应拦截和修改'),
              Text('• Dart - 原生支持，性能更好'),
              Text('• Shell - 系统级脚本和自动化'),
              SizedBox(height: 16),
              Text('使用方法:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('1. 浏览或搜索模板'),
              Text('2. 点击模板查看详情'),
              Text('3. 点击"使用此模板"加载到编辑器'),
              Text('4. 根据需要修改代码'),
              Text('5. 保存并应用脚本'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(ScriptCategory category) {
    switch (category) {
      case ScriptCategory.logging:
        return Colors.blue;
      case ScriptCategory.modification:
        return Colors.orange;
      case ScriptCategory.mock:
        return Colors.purple;
      case ScriptCategory.testing:
        return Colors.green;
      case ScriptCategory.blocking:
        return Colors.red;
      case ScriptCategory.injection:
        return Colors.pink;
      case ScriptCategory.caching:
        return Colors.teal;
      case ScriptCategory.processing:
        return Colors.indigo;
    }
  }

  IconData _getCategoryIcon(ScriptCategory category) {
    switch (category) {
      case ScriptCategory.logging:
        return Icons.list;
      case ScriptCategory.modification:
        return Icons.edit;
      case ScriptCategory.mock:
        return Icons.fake_services;
      case ScriptCategory.testing:
        return Icons.bug_report;
      case ScriptCategory.blocking:
        return Icons.block;
      case ScriptCategory.injection:
        return Icons.code;
      case ScriptCategory.caching:
        return Icons.save;
      case ScriptCategory.processing:
        return Icons.settings;
    }
  }
}
