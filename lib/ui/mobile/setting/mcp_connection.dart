import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/mcp/mcp_server.dart';
import 'package:proxypin/native/mcp_screen.dart';
import 'package:proxypin/utils/ip.dart';
import 'package:proxypin/ui/mobile/setting/mcp_automation.dart';

/// MCP 设置页面
/// 展示 MCP 服务状态、自动启动、连接信息、AI 配置指南、控制模式、可用工具列表
class McpConnectionPage extends StatefulWidget {
  const McpConnectionPage({super.key});

  @override
  State<McpConnectionPage> createState() => _McpConnectionPageState();
}

class _McpConnectionPageState extends State<McpConnectionPage> with WidgetsBindingObserver {
  Map<String, dynamic>? _deviceInfo;
  bool _loading = true;
  String? _deviceIp;

  // 端口输入控制器
  late TextEditingController _portController;
  // 配置中的端口（可能与运行中端口不同）
  int _configuredPort = 9010;
  // MCP 服务是否启用
  bool _mcpEnabled = true;
  // MCP 是否随应用启动自动启动
  bool _mcpAutoStart = false;
  // 工具启用状态（工具名 -> 是否启用）
  Map<String, bool> _toolsEnabled = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _portController = TextEditingController(text: '9010');
    // 注册状态变化回调，实现实时更新
    McpServer().onStatusChanged = _onMcpStatusChanged;
    _loadInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 清除回调，避免页面销毁后仍被调用
    McpServer().onStatusChanged = null;
    _portController.dispose();
    super.dispose();
  }

  /// 监听应用生命周期变化（用于检测从设置页返回）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 从无障碍设置返回后刷新状态
      _refreshDeviceInfo();
    }
  }

  /// MCP 服务器状态变化时刷新 UI
  void _onMcpStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 重新加载设备信息（授权返回后刷新状态）
  Future<void> _loadDeviceInfo() async {
    if (!McpScreen.isSupported) return;
    _deviceInfo = await McpScreen.getDeviceInfo();
  }

  /// 刷新设备信息（静默刷新，不显示 loading）
  Future<void> _refreshDeviceInfo() async {
    if (!McpScreen.isSupported || !mounted) return;
    final info = await McpScreen.getDeviceInfo();
    if (mounted) {
      setState(() => _deviceInfo = info);
    }
  }

  Future<void> _loadInfo() async {
    setState(() => _loading = true);
    try {
      _deviceIp = await localIp();
      final config = await Configuration.instance;
      _configuredPort = config.mcpPort;
      _mcpEnabled = config.mcpEnabled;
      _mcpAutoStart = config.mcpAutoStart;
      _toolsEnabled = Map<String, bool>.from(config.mcpToolsEnabled);
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

  /// 切换自动启动开关
  Future<void> _toggleAutoStart(bool enabled) async {
    final config = await Configuration.instance;
    config.mcpAutoStart = enabled;
    await config.flushConfig();
    setState(() {
      _mcpAutoStart = enabled;
    });
    final loc = AppLocalizations.of(context)!;
    FlutterToastr.show(
      enabled ? loc.mcpAutoStartEnabled : loc.mcpAutoStartDisabled,
      context,
    );
  }

  /// 切换单个工具启用状态
  Future<void> _toggleTool(String name, bool enabled) async {
    final config = await Configuration.instance;
    config.mcpToolsEnabled[name] = enabled;
    await config.flushConfig();
    setState(() {
      _toolsEnabled[name] = enabled;
    });
  }

  /// 应用新端口
  Future<void> _applyPort() async {
    final newPort = int.tryParse(_portController.text.trim());
    if (newPort == null || newPort < 1 || newPort > 65535) {
      final loc = AppLocalizations.of(context)!;
      FlutterToastr.show(loc.mcpPortInvalid, context);
      return;
    }

    if (newPort == _configuredPort) {
      final loc = AppLocalizations.of(context)!;
      FlutterToastr.show(loc.mcpPortUnchanged, context);
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
    final loc = AppLocalizations.of(context)!;
    FlutterToastr.show(loc.mcpPortApplied.replaceAll('{port}', newPort.toString()), context);
  }

  /// 复制文本到剪贴板
  void _copyText(String text, String tip) {
    Clipboard.setData(ClipboardData(text: text));
    FlutterToastr.show(tip, context);
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
    final hasShizuku = _deviceInfo?['hasShizuku'] as bool? ?? false;
    final hasDhizuku = _deviceInfo?['hasDhizuku'] as bool? ?? false;
    final accessibilityEnabled =
        _deviceInfo?['accessibilityEnabled'] as bool? ?? false;

    final configJson = const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        'proxypin': {'url': apiUrl},
      },
    });

    final tools = mcpServer.getTools();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP 设置'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const McpAutomationPage()),
              );
            },
            tooltip: '自动化配置',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // MCP 服务开关与端口配置
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('MCP 服务'),
                        subtitle: Text(
                          _mcpEnabled
                              ? (isRunning
                                    ? '运行中，端口 $port'
                                    : (lastError != null
                                          ? '出错：$lastError'
                                          : '已启用（未运行）'))
                              : '已停用',
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: Icon(
                          _mcpEnabled
                              ? (isRunning
                                    ? Icons.cloud_done
                                    : Icons.cloud_queue)
                              : Icons.cloud_off,
                          color: _mcpEnabled
                              ? (isRunning ? Colors.green : Colors.orange)
                              : Colors.grey,
                        ),
                        value: _mcpEnabled,
                        onChanged: _toggleMcpService,
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        title: const Text('自动启动'),
                        subtitle: const Text(
                          '应用启动时自动运行 MCP 服务（默认开启）',
                          style: TextStyle(fontSize: 12),
                        ),
                        secondary: const Icon(
                          Icons.auto_awesome,
                          color: Colors.purple,
                        ),
                        value: _mcpAutoStart,
                        onChanged: _toggleAutoStart,
                      ),
                      const Divider(height: 0),
                      // 端口配置
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Text('服务端口'),
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
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
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
                              child: const Text('应用'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 连接信息
                Text('连接信息', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'MCP 协议版本：${McpServer.protocolVersion}（无状态核心，兼容旧版握手）',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('设备 IP'),
                        subtitle: Text(ip),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => _copyText(ip, '已复制设备 IP'),
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        title: const Text('API URL（Streamable HTTP）'),
                        subtitle: Text(apiUrl),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => _copyText(apiUrl, '已复制 API URL'),
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        title: const Text('SSE URL（旧版传输）'),
                        subtitle: Text(sseUrl),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => _copyText(sseUrl, '已复制 SSE URL'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // AI 配置指南
                Text('AI 配置指南', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          '将以下配置写入 AI 客户端的 MCP 配置文件中，即可让 '
                          'Cursor / Windsurf / Claude Desktop / Cherry Studio '
                          '等支持 MCP 的 AI 工具读取抓包数据并控制 ProxyPin。'
                          '请确保手机与电脑处于同一局域网，且 MCP 服务已开启。'
                          '服务器同时支持最新无状态协议（2026-07-28）与旧版握手协议。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        color: Colors.grey.shade100,
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                16,
                              ),
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
                                onPressed: () =>
                                    _copyText(configJson, '已复制 AI 配置'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 控制模式
                Text('控制模式', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_applications),
                        title: const Text('当前模式'),
                        trailing: Text(
                          switch (mode) {
                            'none' => 'none',
                            'root' => 'Root',
                            'shizuku' => 'Shizuku',
                            'dhizuku' => 'Dhizuku',
                            'accessibility' => '无障碍',
                            _ => mode,
                          },
                          style: TextStyle(
                            color: mode == 'none'
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: const Text('Root 权限'),
                        trailing: Text(
                          hasRoot ? '可用' : '不可用',
                          style: TextStyle(
                            color: hasRoot ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.security),
                        title: const Text('Shizuku'),
                        trailing: Text(
                          hasShizuku ? '可用' : '不可用',
                          style: TextStyle(
                            color: hasShizuku ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.verified_user),
                        title: const Text('Dhizuku'),
                        trailing: Text(
                          hasDhizuku ? '可用' : '不可用',
                          style: TextStyle(
                            color: hasDhizuku ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.accessibility),
                        title: const Text('无障碍服务'),
                        trailing: Text(
                          accessibilityEnabled ? '可用' : '未开启',
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
                      label: const Text('打开无障碍设置'),
                      onPressed: () async {
                        await McpScreen.openAccessibilitySettings();
                      },
                    ),
                  ),
                ],
                if (McpScreen.isSupported && !hasShizuku) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.security),
                      label: const Text('请求 Shizuku 授权'),
                      onPressed: () async {
                        await McpScreen.requestShizukuAuthorization();
                        // 授权后重新检测状态
                        await _loadDeviceInfo();
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
                if (McpScreen.isSupported && !hasDhizuku) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.verified_user),
                      label: const Text('请求 Dhizuku 授权'),
                      onPressed: () async {
                        await McpScreen.requestDhizukuAuthorization();
                        // 授权后重新检测状态
                        await _loadDeviceInfo();
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
                if (McpScreen.isSupported && !hasRoot) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('请求 Root 授权'),
                      onPressed: () async {
                        await McpScreen.requestRootAuthorization();
                        // 授权后重新检测状态
                        await _loadDeviceInfo();
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // 可用工具列表
                Row(
                  children: [
                    Text(
                      '可用工具',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${tools.length} 个',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '关闭的工具将从工具列表中隐藏，AI 无法调用。',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < tools.length; i++) ...[
                        if (i > 0) const Divider(height: 0, indent: 16),
                        _ToolTile(
                          tool: tools[i],
                          enabled: _toolsEnabled[tools[i]['name']] ?? true,
                          onChanged: (v) =>
                              _toggleTool(tools[i]['name'] as String, v),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新'),
                    onPressed: _loadInfo,
                  ),
                ),
              ],
            ),
    );
  }
}

/// 单个工具卡片：工具名 + 中文备注 + 启用开关
class _ToolTile extends StatelessWidget {
  final Map<String, dynamic> tool;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToolTile({
    required this.tool,
    required this.enabled,
    required this.onChanged,
  });

  /// 工具中文备注
  static const Map<String, String> _notes = {
    'set_config': '修改 ProxyPin 配置（系统代理、SSL 抓包开关）',
    'add_host_mapping': '添加或修改 Host 映射，将域名指向指定 IP',
    'add_response_rewrite': '添加响应重写规则（改状态码、响应头、响应体）',
    'export_har': '将抓包记录导出为 HAR 文件',
    'import_har': '导入 HAR 文件到抓包记录',
    'search_requests': '按 URL、方法、状态码、域名等条件搜索请求',
    'generate_code': '根据请求生成代码（curl、Python、Go、JavaScript、Node.js）',
    'get_curl': '生成请求对应的 cURL 命令',
    'get_recent_requests': '获取最近抓到的请求列表',
    'get_request_details': '获取指定请求的完整详情（请求/响应头与体、Cookie）',
    'start_proxy': '启动代理服务',
    'stop_proxy': '停止代理服务',
    'get_proxy_status': '查询代理服务运行状态',
    'clear_requests': '清空抓包记录',
    'replay_request': '重放指定请求',
    'block_url': '屏蔽指定 URL 的请求',
    'add_request_rewrite': '添加请求重写规则',
    'update_script': '更新注入页面的 JS 脚本',
    'get_scripts': '获取已配置的 JS 脚本列表',
    'get_statistics': '获取抓包统计信息',
    'compare_requests': '对比两个请求的差异',
    'find_similar_requests': '查找与指定请求相似的请求',
    'extract_api_endpoints': '从抓包记录中提取 API 端点聚合信息',
    'analyze_auth': '分析请求中的认证信息（Authorization、Token、Cookie、API Key）',
    'find_sensitive_data': '搜索请求中的敏感数据（密码、密钥、手机号、身份证等）',
    'get_cookie_info': '分析域名的 Cookie（值、HttpOnly、Secure、过期时间）',
    'get_domain_summary': '统计域名的流量摘要（方法、状态码、平均耗时、错误数）',
    'calculate_entropy': '计算字符串香农熵，评估随机性与密钥强度',
    'get_pending_intercepts': '查看断点拦截队列中待处理的请求/响应',
    'approve_intercept': '放行断点拦截（可修改请求后放行）',
    'reject_intercept': '拒绝断点拦截（中止请求或丢弃响应）',
    'add_breakpoint_rule': '添加断点拦截规则',
    'remove_breakpoint_rule': '移除断点拦截规则',
    'list_breakpoint_rules': '列出所有断点拦截规则',
    'toggle_breakpoint': '启用或停用断点拦截',
    'add_weak_network_rule': '添加弱网模拟规则（限速、延迟等）',
    'add_custom_network_profile': '添加自定义网络档位',
    'list_weak_network_rules': '列出所有弱网规则',
    'remove_weak_network_rule': '移除弱网规则',
    'toggle_weak_network': '启用或停用弱网模拟',
    'list_environments': '列出所有环境',
    'set_environment_variable': '设置环境变量值',
    'create_environment': '创建新环境',
    'set_active_environment': '切换当前活动环境',
    'remove_environment': '删除指定环境',
    'toggle_environment_variables': '启用或停用环境变量',
    'get_device_info': '获取设备信息（型号、系统版本、Root 状态）',
    'get_current_activity': '获取当前前台 Activity',
    'dump_ui': '导出当前界面的 UI 层级树',
    'tap_screen': '模拟点击屏幕坐标',
    'long_press': '模拟长按屏幕坐标',
    'swipe_screen': '模拟滑动屏幕',
    'key_event': '发送按键事件（如返回键、音量键）',
    'input_text': '向当前输入框输入文本',
    'screenshot': '截取当前屏幕',
    'open_accessibility_settings': '打开系统无障碍设置页',
    'shell': '执行 Shell 命令（支持 Root/Shizuku/Dhizuku 模式）',
  };

  @override
  Widget build(BuildContext context) {
    final name = tool['name'] as String? ?? '';
    final note = _notes[name] ?? (tool['description'] as String? ?? '');
    return ListTile(
      dense: true,
      title: Text(
        name,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          note,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Switch(value: enabled, onChanged: onChanged),
    );
  }
}
