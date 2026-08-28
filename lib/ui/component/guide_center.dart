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
import 'package:flutter/services.dart' show rootBundle;

/// 内置文档中心：离线查看全部功能使用教程、规范文档与开发文档。
///
/// 文档以 Markdown 资源打包（见 pubspec.yaml assets），运行时按需加载，
/// 由轻量渲染器展示（标题/列表/代码块/引用/分隔线/表格文本化）。
class GuideDoc {
  final String id;
  final String title;
  final String category;
  final String assetPath;
  final IconData icon;

  const GuideDoc(this.id, this.title, this.category, this.assetPath, this.icon);
}

class GuideCenter {
  GuideCenter._();

  /// 内置文档清单（id 即 asset 相对路径的 key）
  static const List<GuideDoc> docs = [
    GuideDoc('quick_start', '快速上手', '快速上手', 'docs/quick_start.md', Icons.rocket_launch_outlined),
    GuideDoc('certificate_https', '证书与 HTTPS 抓包', '快速上手', 'docs/certificate_https.md', Icons.security_outlined),
    GuideDoc('features_tips', '常用功能技巧', '快速上手', 'docs/features_tips.md', Icons.tips_and_updates_outlined),
    GuideDoc('mcp_automation', 'MCP 自动化指南', '自动化', 'docs/MCP_AUTOMATION_GUIDE.md', Icons.smart_toy_outlined),
    GuideDoc('workflow_tutorial', '工作流编排教程', '自动化', 'docs/WORKFLOW_TUTORIAL.md', Icons.account_tree_outlined),
    GuideDoc('changelog', '更新日志', '文档', 'CHANGELOG.md', Icons.history),
    GuideDoc('agents', '开发文档', '文档', 'AGENTS.md', Icons.code),
    GuideDoc('readme_cn', '项目说明', '文档', 'README_CN.md', Icons.description_outlined),
  ];

  static GuideDoc? byId(String id) {
    for (final d in docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// 加载文档内容
  static Future<String> load(GuideDoc doc) async {
    try {
      return await rootBundle.loadString(doc.assetPath);
    } catch (e) {
      return '文档加载失败：$e';
    }
  }
}

/// 文档中心页面：按分类分组的文档列表 + 搜索
class GuideCenterPage extends StatefulWidget {
  const GuideCenterPage({super.key});

  @override
  State<GuideCenterPage> createState() => _GuideCenterPageState();
}

class _GuideCenterPageState extends State<GuideCenterPage> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final filtered = GuideCenter.docs
        .where((d) => _keyword.isEmpty || d.title.contains(_keyword) || d.category.contains(_keyword))
        .toList();

    // 按分类分组（保持清单顺序）
    final categories = <String>[];
    for (final d in filtered) {
      if (!categories.contains(d.category)) categories.add(d.category);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('使用文档', style: TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: '搜索文档',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _keyword = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final docs = filtered.where((d) => d.category == category).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
                      child: Text(category,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        children: [
                          for (final doc in docs)
                            ListTile(
                              dense: true,
                              leading: Icon(doc.icon, size: 20, color: Theme.of(context).colorScheme.primary),
                              title: Text(doc.title, style: const TextStyle(fontSize: 14)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => GuideArticlePage(doc: doc)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 单篇文档阅读页
class GuideArticlePage extends StatefulWidget {
  final GuideDoc doc;

  const GuideArticlePage({super.key, required this.doc});

  @override
  State<GuideArticlePage> createState() => _GuideArticlePageState();
}

class _GuideArticlePageState extends State<GuideArticlePage> {
  String? _content;

  @override
  void initState() {
    super.initState();
    GuideCenter.load(widget.doc).then((content) {
      if (mounted) setState(() => _content = content);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc.title, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: _content == null
          ? const Center(child: CircularProgressIndicator())
          : MarkdownLiteView(content: _content!),
    );
  }
}

/// 轻量 Markdown 渲染视图（无第三方依赖）：
/// 支持 #/##/### 标题、- 与 1. 列表、``` 代码块、> 引用、--- 分隔线、表格文本化、**粗体**。
class MarkdownLiteView extends StatelessWidget {
  final String content;

  const MarkdownLiteView({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = content.split('\n');
    final widgets = <Widget>[];
    final buffer = <String>[];
    bool inCode = false;
    final codeLines = <String>[];

    // 粗体解析：**text**
    List<InlineSpan> parseInline(String text, TextStyle base) {
      final spans = <InlineSpan>[];
      final reg = RegExp(r'\*\*(.+?)\*\*');
      int last = 0;
      for (final m in reg.allMatches(text)) {
        if (m.start > last) {
          spans.add(TextSpan(text: text.substring(last, m.start), style: base));
        }
        spans.add(TextSpan(
            text: m.group(1),
            style: base.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)));
        last = m.end;
      }
      if (last < text.length) {
        spans.add(TextSpan(text: text.substring(last), style: base));
      }
      return spans.isEmpty ? [TextSpan(text: text, style: base)] : spans;
    }

    void flushParagraph() {
      if (buffer.isEmpty) return;
      final text = buffer.join('\n');
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SelectableText.rich(
          TextSpan(children: parseInline(text, theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))),
        ),
      ));
      buffer.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          widgets.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? Colors.grey[900] : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              codeLines.join('\n'),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFD4D4D4), height: 1.5),
            ),
          ));
          codeLines.clear();
          inCode = false;
        } else {
          flushParagraph();
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        codeLines.add(raw);
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }
      if (trimmed == '---' || trimmed == '***') {
        flushParagraph();
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(thickness: 0.5),
        ));
        continue;
      }
      if (trimmed.startsWith('### ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(trimmed.substring(4),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(trimmed.substring(3),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(trimmed.substring(2),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ));
        continue;
      }
      if (trimmed.startsWith('> ')) {
        flushParagraph();
        widgets.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(width: 3, color: theme.colorScheme.primary)),
          ),
          child: Text(trimmed.substring(2), style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
        ));
        continue;
      }
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        buffer.add('• ${trimmed.substring(2)}');
        continue;
      }
      final numbered = RegExp(r'^(\d+)\.\s+(.*)');
      if (numbered.hasMatch(trimmed)) {
        final m = numbered.firstMatch(trimmed)!;
        buffer.add('${m.group(1)}. ${m.group(2)}');
        continue;
      }
      if (trimmed.startsWith('|')) {
        // 表格行：按原样等宽展示（配合上下空行区分）
        buffer.add(trimmed);
        continue;
      }
      buffer.add(trimmed);
    }
    flushParagraph();
    if (inCode && codeLines.isNotEmpty) {
      widgets.add(SelectableText(codeLines.join('\n'),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace')));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
    );
  }
}

/// 打开文档中心（全部文档）
void showGuideCenter(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const GuideCenterPage()));
}

/// 打开指定文档（供各功能页的单篇教程入口）
void showGuideArticle(BuildContext context, String docId) {
  final doc = GuideCenter.byId(docId);
  if (doc == null) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => GuideArticlePage(doc: doc)));
}
