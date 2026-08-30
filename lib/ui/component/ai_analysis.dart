/*
 * AI 分析 UI：分析结果弹窗 + 偏好设置里的 AI 配置编辑弹窗（上游 #582）
 */
import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/components/ai_analyzer.dart';
import 'package:proxypin/network/http/http.dart';

/// 对单个请求做 AI 分析并弹窗展示结果
Future<void> showAiAnalysis(BuildContext context, HttpRequest request) async {
  if (!AiAnalyzer.isConfigured) {
    final configured = await showAiSettingsDialog(context);
    if (configured != true) return;
  }

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('AI 分析 · ${request.method} ${request.path}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
              ]),
              const Divider(),
              Flexible(
                child: FutureBuilder<String>(
                  future: AiAnalyzer.analyze(request),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('正在分析…', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ]));
                    }
                    if (snap.hasError) {
                      return SelectableText('分析失败：${snap.error}',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error));
                    }
                    return SingleChildScrollView(
                        child: SelectableText(snap.data ?? '', style: const TextStyle(fontSize: 13.5, height: 1.5)));
                  },
                ),
              ),
            ]),
          ),
        ),
      );
    },
  );
}

/// AI 配置编辑（baseUrl / apiKey / model），返回 true 表示已保存且可用
Future<bool?> showAiSettingsDialog(BuildContext context) async {
  final config = Configuration.loaded;
  if (config == null) return false;
  final baseUrlController = TextEditingController(text: config.aiBaseUrl);
  final keyController = TextEditingController(text: config.aiApiKey);
  final modelController = TextEditingController(text: config.aiModel);
  var enabled = config.aiEnabled;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('AI 分析配置', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用 AI 分析', style: TextStyle(fontSize: 14)),
                subtitle: const Text('OpenAI 兼容接口，数据将发送到你配置的服务',
                    style: TextStyle(fontSize: 12)),
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
              ),
              TextField(
                controller: baseUrlController,
                decoration: const InputDecoration(
                  labelText: '接口地址 (Base URL)',
                  hintText: 'https://api.openai.com/v1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: '模型',
                  hintText: 'gpt-4o-mini / deepseek-chat / qwen-plus …',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              config.aiEnabled = enabled;
              config.aiBaseUrl = baseUrlController.text.trim();
              config.aiApiKey = keyController.text.trim();
              config.aiModel = modelController.text.trim().isEmpty ? 'gpt-4o-mini' : modelController.text.trim();
              config.flushConfig();
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );

  if (result == true && context.mounted) {
    FlutterToastr.show('AI 配置已保存', context, backgroundColor: Colors.green);
  }
  return result;
}
