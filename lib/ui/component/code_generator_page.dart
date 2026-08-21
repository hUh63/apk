/*
 * 代码生成器页面 - 支持多种语言 HTTP 请求代码生成
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/util/code_generator.dart';
import 'package:proxypin/l10n/app_localizations.dart';

/// 代码生成器页面
class CodeGeneratorPage extends StatefulWidget {
  final Request request;

  const CodeGeneratorPage({super.key, required this.request});

  @override
  State<CodeGeneratorPage> createState() => _CodeGeneratorPageState();
}

class _CodeGeneratorPageState extends State<CodeGeneratorPage> {
  final CodeGenerator _generator = CodeGenerator();
  CodeLanguage _selectedLanguage = CodeLanguage.curl;
  String _generatedCode = '';
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  void _generateCode() {
    setState(() {
      _generatedCode = _generator.generate(widget.request, _selectedLanguage);
      _copied = false;
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedCode));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('代码生成'),
        actions: [
          IconButton(
            icon: Icon(_copied ? Icons.check : Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: _copied ? '已复制' : '复制代码',
          ),
        ],
      ),
      body: Column(
        children: [
          // 语言选择器
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择编程语言',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CodeLanguage.values.map((lang) {
                    final isSelected = _selectedLanguage == lang;
                    return ChoiceChip(
                      label: Text(lang.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedLanguage = lang);
                          _generateCode();
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // 请求预览
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '请求预览',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('方法', widget.request.method),
                    _buildInfoRow('URL', widget.request.url),
                    if (widget.request.body.isNotEmpty)
                      _buildInfoRow('请求体', '${widget.request.body.length} 字符'),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 代码显示区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _generatedCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // 语言标签
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _selectedLanguage.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 代码生成工具函数
class CodeGeneratorUtils {
  static void showCodeGenerator(BuildContext context, Request request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CodeGeneratorPage(request: request),
      ),
    );
  }
}
