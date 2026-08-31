/*
 * AI 分析对话页（上游 #582）
 * - 完整页面：消息气泡对话 + 附加抓包请求作为上下文 + AI 配置入口
 * - 请求来源：McpBridge 的最近请求容器（与 MCP 工具同源）
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/components/ai_analyzer.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/mcp/mcp_bridge.dart';

class AiChatPage extends StatefulWidget {
  /// 进入页面时自动附加的请求（如从请求长按菜单进入）
  final HttpRequest? initialRequest;

  const AiChatPage({super.key, this.initialRequest});

  @override
  State<StatefulWidget> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// 对话消息（role: user / assistant）
  final List<_ChatMessage> _messages = [];

  /// 待附加的抓包请求（随下一条消息发送）
  HttpRequest? _attachedRequest;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _attachedRequest = widget.initialRequest;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    if (!AiAnalyzer.isConfigured) {
      final saved = await showAiSettingsDialog(context);
      if (saved != true || !AiAnalyzer.isConfigured) return;
    }

    var content = text;
    if (_attachedRequest != null) {
      content = '$text\n\n---\n附加抓包请求：\n${AiAnalyzer.requestSummary(_attachedRequest!)}';
    }

    final attached = _attachedRequest;
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text, attachedRequest: attached));
      _attachedRequest = null;
      _inputController.clear();
      _sending = true;
    });
    _scrollToBottom();

    try {
      // 组装多轮上下文（不含本地展示字段）
      final apiMessages = _messages
          .map((m) => {'role': m.role, 'content': m.apiContent})
          .toList();
      final reply = await AiAnalyzer.chat(apiMessages);
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: reply));
        _sending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: '分析失败：$e', isError: true));
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// 从最近抓包请求中选择要附加的请求
  Future<void> _pickRequest() async {
    final requests = McpBridge().getRecentRequests(limit: 30);
    if (requests.isEmpty) {
      FlutterToastr.show('暂无抓包请求', context);
      return;
    }
    final selected = await showModalBottomSheet<HttpRequest>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return ListTile(
              dense: true,
              leading: Text(req.method.name,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              title: Text(req.requestUrl,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
              subtitle: req.response != null
                  ? Text('状态码 ${req.response!.status.code}', style: const TextStyle(fontSize: 11))
                  : const Text('未响应', style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(context, req),
            );
          },
        ),
      ),
    );
    if (selected != null) {
      setState(() => _attachedRequest = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 分析', style: TextStyle(fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file, size: 20),
            tooltip: '附加抓包请求',
            onPressed: _pickRequest,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'AI 配置',
            onPressed: () async {
              await showAiSettingsDialog(context);
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(children: [
        // 附加请求提示条
        if (_attachedRequest != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.link, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '已附加：${_attachedRequest!.method.name} ${_attachedRequest!.requestUrl}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _attachedRequest = null),
                child: Icon(Icons.close, size: 15, color: cs.outline),
              ),
            ]),
          ),
        // 消息区
        Expanded(
          child: _messages.isEmpty
              ? _emptyState(cs)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _bubble(_messages[index]),
                ),
        ),
        if (_sending)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('AI 正在思考…', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        // 输入区
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '输入问题，可先附加请求作为上下文',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send, size: 18),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.auto_awesome, size: 44, color: cs.primary.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text('与 AI 对话分析抓包数据', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('点击右上角 📎 附加一条抓包请求，或直接提问',
            style: TextStyle(fontSize: 12, color: cs.outline)),
      ]),
    );
  }

  Widget _bubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: msg.isError
              ? cs.errorContainer.withValues(alpha: 0.5)
              : isUser
                  ? cs.primary.withValues(alpha: 0.12)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 3),
            bottomRight: Radius.circular(isUser ? 3 : 12),
          ),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (msg.attachedRequest != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '📎 ${msg.attachedRequest!.method.name} ${msg.attachedRequest!.requestUrl}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.primary, fontStyle: FontStyle.italic),
              ),
            ),
          SelectableText(
            msg.content,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: msg.isError ? cs.error : null),
          ),
          if (!isUser && !msg.isError) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                FlutterToastr.show('已复制', context);
              },
              child: Icon(Icons.copy, size: 13, color: cs.outline),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  final HttpRequest? attachedRequest;
  final bool isError;

  /// 发送给 API 的内容：附加请求的摘要并入 user 消息
  String get apiContent {
    if (role == 'user' && attachedRequest != null) {
      return '$content\n\n---\n附加抓包请求：\n${AiAnalyzer.requestSummary(attachedRequest!)}';
    }
    return content;
  }

  _ChatMessage({required this.role, required this.content, this.attachedRequest, this.isError = false});
}

/// AI 配置编辑（baseUrl / apiKey / model），返回 true 表示已保存
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
