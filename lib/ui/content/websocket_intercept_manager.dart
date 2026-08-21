import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/mcp/mcp_bridge.dart';
import 'package:proxypin/network/http/websocket.dart';
import 'package:proxypin/ui/component/app_dialog.dart';
import 'package:proxypin/ui/component/json/json_text.dart';
import 'package:proxypin/ui/component/json/json_viewer.dart';
import 'package:proxypin/ui/component/json/theme.dart';
import 'package:proxypin/utils/lang.dart';

/// WebSocket 拦截管理界面 (v1.6.0+)
/// 显示所有暂停的 WebSocket 消息，支持恢复/中止/修改
class WebSocketInterceptManager extends StatefulWidget {
  const WebSocketInterceptManager({super.key});

  @override
  State<WebSocketInterceptManager> createState() => _WebSocketInterceptManagerState();
}

class _WebSocketInterceptManagerState extends State<WebSocketInterceptManager> {
  List<PausedWebSocketFrame> _pausedMessages = [];
  bool _isInterceptEnabled = false;

  @override
  void initState() {
    super.initState();
    _isInterceptEnabled = McpBridge().webSocketInterceptEnabled;
    _loadPausedMessages();
  }

  void _loadPausedMessages() {
    setState(() {
      _pausedMessages = McpBridge().getPausedWebSocketMessages();
    });
  }

  void _toggleIntercept(bool enabled) {
    McpBridge().setWebSocketInterceptEnabled(enabled);
    setState(() {
      _isInterceptEnabled = enabled;
    });
    if (enabled) {
      _loadPausedMessages();
    }
  }

  void _resumeMessage(PausedWebSocketFrame frame) {
    McpBridge().resumeWebSocketMessage(frame.frameId);
    _loadPausedMessages();
    if (mounted) {
      CustomToast.success('消息已恢复').show(context);
    }
  }

  void _resumeWithModification(PausedWebSocketFrame frame) {
    showDialog(
      context: context,
      builder: (context) => _ModifyPayloadDialog(
        frame: frame,
        onConfirm: (newPayload) {
          McpBridge().resumeWebSocketMessage(frame.frameId, payload: newPayload);
          _loadPausedMessages();
          if (mounted) {
            CustomToast.success('消息已修改并恢复').show(context);
          }
        },
      ),
    );
  }

  void _abortMessage(PausedWebSocketFrame frame) {
    McpBridge().abortWebSocketMessage(frame.frameId);
    _loadPausedMessages();
    if (mounted) {
      CustomToast.success('消息已中止').show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        // 顶部控制栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isInterceptEnabled ? Colors.green.shade50 : Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              Switch(
                value: _isInterceptEnabled,
                onChanged: _toggleIntercept,
                activeColor: Colors.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WebSocket 拦截',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _isInterceptEnabled ? '拦截已启用 - 新消息将被暂停' : '拦截已禁用 - 消息直接放行',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (_pausedMessages.isNotEmpty)
                Text(
                  '${_pausedMessages.length} 条暂停',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isInterceptEnabled ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),

        // 消息列表
        Expanded(
          child: _pausedMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.web_asset_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isInterceptEnabled ? '暂无暂停的消息' : '启用拦截以开始捕获 WebSocket 消息',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _pausedMessages.length,
                  itemBuilder: (context, index) {
                    final frame = _pausedMessages[index];
                    return _PausedMessageCard(
                      frame: frame,
                      onResume: () => _resumeMessage(frame),
                      onModify: () => _resumeWithModification(frame),
                      onAbort: () => _abortMessage(frame),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PausedMessageCard extends StatelessWidget {
  final PausedWebSocketFrame frame;
  final VoidCallback onResume;
  final VoidCallback onModify;
  final VoidCallback onAbort;

  const _PausedMessageCard({
    required this.frame,
    required this.onResume,
    required this.onModify,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(frame.pausedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部信息
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 方向标识
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: frame.isOutgoing ? Colors.green.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    frame.isOutgoing ? 'OUT' : 'IN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: frame.isOutgoing ? Colors.green.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Opcode 标识
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _opcodeToString(frame.opcode),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                // 暂停时长
                Text(
                  '暂停 ${duration.inSeconds}s',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // URL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              frame.url,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Payload 预览
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                frame.payloadPreview,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 操作按钮
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onModify,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('修改'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('恢复'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAbort,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('中止'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _opcodeToString(int opcode) {
    switch (opcode) {
      case 0x01:
        return 'Text';
      case 0x02:
        return 'Binary';
      case 0x08:
        return 'Close';
      case 0x09:
        return 'Ping';
      case 0x0A:
        return 'Pong';
      default:
        return '0x${opcode.toRadixString(16)}';
    }
  }
}

class _ModifyPayloadDialog extends StatefulWidget {
  final PausedWebSocketFrame frame;
  final Function(String) onConfirm;

  const _ModifyPayloadDialog({
    required this.frame,
    required this.onConfirm,
  });

  @override
  State<_ModifyPayloadDialog> createState() => _ModifyPayloadDialogState();
}

class _ModifyPayloadDialogState extends State<_ModifyPayloadDialog> {
  late TextEditingController _controller;
  int tabIndex = 0;

  @override
  void initState() {
    super.initState();
    try {
      _controller = TextEditingController(
        text: utf8.decode(widget.frame.payload, allowMalformed: true),
      );
    } catch (e) {
      _controller = TextEditingController(text: '');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: "Text"),
      const Tab(text: "JSON"),
      const Tab(text: "HEX"),
    ];

    return AlertDialog(
      title: const Text('修改 Payload'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.6,
        child: DefaultTabController(
          length: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TabBar(tabs: tabs),
              Expanded(
                child: TabBarView(
                  children: [
                    // Text 编辑
                    TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '输入新的 payload 文本',
                      ),
                    ),
                    // JSON 预览
                    _buildJsonView(),
                    // HEX 预览
                    _buildHexView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onConfirm(_controller.text);
          },
          child: const Text('确认'),
        ),
      ],
    );
  }

  Widget _buildJsonView() {
    try {
      final text = _controller.text;
      final jsonData = json.decode(text);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: JsonText(
          json: jsonData,
          indent: '  ',
          colorTheme: ColorTheme.of(context),
        ),
      );
    } catch (e) {
      return Center(
        child: Text('无效的 JSON: $e', style: TextStyle(color: Colors.red.shade700)),
      );
    }
  }

  Widget _buildHexView() {
    try {
      final bytes = utf8.encode(_controller.text);
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      return SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: SelectableText(hex, style: const TextStyle(fontFamily: 'monospace')),
      );
    } catch (e) {
      return const Center(child: Text('无法编码为 HEX'));
    }
  }
}
