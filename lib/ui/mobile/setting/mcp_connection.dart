import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/mcp/mcp_server.dart';
import 'package:proxypin/native/mcp_screen.dart';
import 'package:proxypin/utils/ip.dart';

/// MCP Connection 设置页面
/// 展示 MCP 服务器状态、连接信息、控制模式、服务开关、端口配置和配置 JSON
class McpConnectionPage extends StatefulWidget {
  const McpConnectionPage({super.key});

  @override
  State<McpConnectionPage> createState() => _McpConnectionPageState();
}

class _McpConnectionPageState extends State<McpConnectionPage> {
  Map<String, dynamic>? _deviceInfo;
  bool _loading = true;
  String? _deviceIp;

  // 端口输入控制器
  late TextEditingController _portController;
  // 配置中的端口（可能与运行中端口不同）
  int _configuredPort = 9010;
  // MCP 服务是否启用
  bool _mcpEnabled = true;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: '9010');
    // 注册状态变化回调，实现实时更新
    McpServer().onStatusChanged = _onMcpStatusChanged;
    _loadInfo();
  }

  @override
  void dispose() {
    // 清除回调，避免页面销毁后仍被调用
    McpServer().onStatusChanged = null;
    _portController.dispose();
    super.dispose();
  }

  /// MCP 服务器状态变化时刷新 UI
  void _onMcpStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadInfo() async {
    setState(() => _loading = true);
    try {
      _deviceIp = await localIp();
      final config = await Configuration.instance;
      _configuredPort = config.mcpPort;
      _mcpEnabled = config.mcpEnabled;
      _portController.text = _configuredPort.toString();
      if (McpScreen.isSupported) {
        _deviceInfo = await McpScreen.getDeviceInfo();
      }
    } catch (e) {
      // ignore
    }
    setState(() => _loading = false);
  }

  /// 切换 MCP 服务开关
  Future<void> _toggleMcpService(bool enabled) async {
    final config = await Configuration.instance;
    config.mcpEnabled = enabled;
    await config.flushConfig();

    if (enabled) {
      await McpServer().start();
    } else {
      await McpServer().stop();
    }

    setState(() {
      _mcpEnabled = enabled;
    });
  }

  /// 应用新端口
  Future<void> _applyPort() async {
    final newPort = int.tryParse(_portController.text.trim());
    if (newPort == null || newPort < 1 || newPort > 65535) {
      FlutterToastr.show('Invalid port number (1-65535)', context);
      return;
    }

    if (newPort == _configuredPort) {
      FlutterToastr.show('Port unchanged', context);
      return;
    }

    final config = await Configuration.instance;
    config.mcpPort = newPort;
    await config.flushConfig();

    // 如果 MCP 服务正在运行，重启以应用新端口
    if (config.mcpEnabled) {
      await McpServer().restart();
    }

    setState(() {
      _configuredPort = newPort;
    });
    FlutterToastr.show('Port applied: $newPort', context);
  }

  @override
  Widget build(BuildContext context) {
    final mcpServer = McpServer();
    final port = _configuredPort;
    final ip = _deviceIp ?? '127.0.0.1';
    final apiUrl = 'http://$ip:$port/mcp';
    final sseUrl = 'http://$ip:$port/sse';
    final isRunning = mcpServer.isRunning;
    final lastError = mcpServer.lastError;

    final mode = _deviceInfo?['mode'] as String? ?? 'none';
    final hasRoot = _deviceInfo?['hasRoot'] as bool? ?? false;
    final accessibilityEnabled =
        _deviceInfo?['accessibilityEnabled'] as bool? ?? false;

    final configJson = const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        'proxypin': {
          'url': apiUrl,
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Connection'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // MCP Service Toggle & Port Configuration
                Card(
                  child: Column(
                    children: [
                      // Service Enable/Disable Switch
                      SwitchListTile(
                        title: const Text('MCP Service'),
                        subtitle: Text(_mcpEnabled
                            ? (isRunning
                                ? 'Running on port $port'
                                : (lastError != null
                                    ? 'Error: $lastError'
                                    : 'Enabled (not running)'))
                            : 'Disabled'),
                        secondary: Icon(
                          _mcpEnabled
                              ? (isRunning ? Icons.cloud_done : Icons.cloud_queue)
                              : Icons.cloud_off,
                          color: _mcpEnabled
                              ? (isRunning ? Colors.green : Colors.orange)
                              : Colors.grey,
                        ),
                        value: _mcpEnabled,
                        onChanged: _toggleMcpService,
                      ),
                      const Divider(height: 0),
                      // Port Configuration
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Text('Service Port'),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: TextField(
                                  controller: _portController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(),
                                    hintText: '9010',
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  onSubmitted: (_) => _applyPort(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _applyPort,
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Connection Info
                Text('Connection Info',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Device IP'),
                        subtitle: Text(ip),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: ip));
                            FlutterToastr.show('Copied', context);
                          },
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        title: const Text('API URL'),
                        subtitle: Text(apiUrl),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: apiUrl));
                            FlutterToastr.show('Copied', context);
                          },
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        title: const Text('SSE URL'),
                        subtitle: Text(sseUrl),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: sseUrl));
                            FlutterToastr.show('Copied', context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Control Mode
                Text('Control Mode',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_applications),
                        title: const Text('Current Mode'),
                        trailing: Text(
                          mode,
                          style: TextStyle(
                            color:
                                mode == 'none' ? Colors.orange : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: const Text('Root Access'),
                        trailing: Text(
                          hasRoot ? 'Available' : 'Not available',
                          style: TextStyle(
                            color: hasRoot ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.accessibility),
                        title: const Text('Accessibility'),
                        trailing: Text(
                          accessibilityEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            color: accessibilityEnabled
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!accessibilityEnabled && McpScreen.isSupported) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.accessibility),
                      label: const Text('Open Accessibility Settings'),
                      onPressed: () async {
                        await McpScreen.openAccessibilitySettings();
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // MCP Config
                Text('MCP Config (for Claude/Windsurf/Cursor)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  color: Colors.grey.shade100,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          configJson,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: configJson));
                            FlutterToastr.show('Copied', context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: _loadInfo,
                  ),
                ),
              ],
            ),
    );
  }
}
