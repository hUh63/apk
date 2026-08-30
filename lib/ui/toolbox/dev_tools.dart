/*
 * 开发者小工具集：JWT 解码 · UUID 生成 · SHA 哈希 · Cron 表达式
 * 统一浅排版、跟随主题，移动端/桌面端均可直接导航打开。
 */
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:proxypin/network/util/cron_expression.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';

/// 在工具箱展示的入口页：单页 Tab 形式，减少多页面跳转
class DevToolsPage extends StatefulWidget {
  final int initialIndex;

  const DevToolsPage({super.key, this.initialIndex = 0});

  @override
  State<StatefulWidget> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialIndex.clamp(0, 3));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开发工具', style: TextStyle(fontSize: 16)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Cron 表达式'),
            Tab(text: 'JWT 解码'),
            Tab(text: 'UUID'),
            Tab(text: 'SHA 哈希'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabController, children: const [
        CronToolPage(),
        JwtDecodePage(),
        UuidToolPage(),
        ShaHashPage(),
      ]),
    );
  }
}

// ==================== Cron 表达式 ====================

/// Cron 表达式工具：字段说明 + 常用示例 + 未来执行时间预览
/// 支持「分 时 日 月 星期」，通配符 * , - /
class CronToolPage extends StatefulWidget {
  const CronToolPage({super.key});

  @override
  State<StatefulWidget> createState() => _CronToolPageState();
}

class _CronToolPageState extends State<CronToolPage> {
  final TextEditingController _controller = TextEditingController(text: '0 9 * * 1-5');
  List<DateTime> _nextTimes = [];
  String? _error;

  static const List<(String, String)> _examples = [
    ('0 9 * * 1-5', '工作日每天上午 9 点'),
    ('30 8 1 * *', '每月 1 号 8:30'),
    ('0 0 * * *', '每天零点'),
    ('*/15 * * * *', '每 15 分钟'),
    ('0 */2 * * *', '每 2 小时'),
    ('0 12 * * 1', '每周一中午 12 点'),
  ];

  @override
  void initState() {
    super.initState();
    _evaluate(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _evaluate(String input) {
    final cron = CronExpression(input);
    final times = <DateTime>[];
    var t = DateTime.now();
    for (var i = 0; i < 6; i++) {
      final next = cron.next(t);
      if (next == null) {
        setState(() {
          _nextTimes = [];
          _error = '无法解析该表达式，请检查各字段';
        });
        return;
      }
      times.add(next);
      t = next;
    }
    setState(() {
      _nextTimes = times;
      _error = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    final fields = [
      ('分钟', '0-59'),
      ('小时', '0-23'),
      ('日', '1-31'),
      ('月', '1-12'),
      ('星期', '0-6（0 为周日）'),
    ];
    final input = _controller.text.trim();
    final parts = input.isEmpty ? <String>[] : input.split(RegExp(r'\s+'));

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Cron 表达式',
            hintText: '分 时 日 月 星期',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.play_arrow, size: 20),
              tooltip: '解析',
              onPressed: () => _evaluate(_controller.text),
            ),
          ),
          onSubmitted: _evaluate,
        ),
        const SizedBox(height: 6),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
        if (_nextTimes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('接下来 6 次执行时间',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 6),
          ..._nextTimes.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(Icons.schedule, size: 15, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 6),
                  Text('${t.year}-'
                      '${t.month.toString().padLeft(2, '0')}-'
                      '${t.day.toString().padLeft(2, '0')} '
                      '${t.hour.toString().padLeft(2, '0')}:'
                      '${t.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 14)),
                ]),
              )),
        ],
        const Divider(height: 28),
        Text('字段说明', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 6),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.6)},
          border: TableBorder.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3), width: 0.5),
          children: [
            for (final (i, f) in fields.indexed)
              TableRow(children: [
                Padding(padding: const EdgeInsets.all(6), child: Text(f.$1, style: const TextStyle(fontSize: 13))),
                Padding(padding: const EdgeInsets.all(6), child: Text(f.$2, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(parts.length > i ? parts[i] : '-', style: const TextStyle(fontSize: 12))),
              ]),
          ],
        ),
        const SizedBox(height: 8),
        Text('支持通配符：* 任意值 · , 列表 · - 范围 · / 步进', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Divider(height: 28),
        Text('常用示例（点击填入）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (expr, desc) in _examples)
              ActionChip(
                label: Text(desc, style: const TextStyle(fontSize: 12)),
                tooltip: expr,
                onPressed: () {
                  _controller.text = expr;
                  _evaluate(expr);
                },
              ),
          ],
        ),
      ],
    );
  }
}

// ==================== JWT 解码 ====================

class JwtDecodePage extends StatefulWidget {
  const JwtDecodePage({super.key});

  @override
  State<StatefulWidget> createState() => _JwtDecodePageState();
}

class _JwtDecodePageState extends State<JwtDecodePage> {
  final TextEditingController _controller = TextEditingController();

  String? _header;
  String? _payload;
  String? _error;
  Map<String, dynamic>? _claims;

  void _decode() {
    setState(() {
      _header = null;
      _payload = null;
      _error = null;
      _claims = null;
    });
    final token = _controller.text.trim().replaceFirst(RegExp('^Bearer ', caseSensitive: false), '');
    final parts = token.split('.');
    if (parts.length < 2) {
      setState(() => _error = 'JWT 应由两段以上 Base64Url 组成（header.payload.signature）');
      return;
    }
    try {
      final header = utf8.decode(_base64UrlDecode(parts[0]));
      final payload = utf8.decode(_base64UrlDecode(parts[1]));
      final headerMap = jsonDecode(header);
      final claims = payload.isEmpty ? null : jsonDecode(payload);
      setState(() {
        _header = const JsonEncoder.withIndent('  ').convert(headerMap);
        _payload = const JsonEncoder.withIndent('  ').convert(jsonDecode(payload));
        _claims = claims is Map<String, dynamic> ? claims : null;
      });
    } catch (e) {
      setState(() => _error = '解码失败：$e');
    }
  }

  /// 补齐 Base64Url padding
  List<int> _base64UrlDecode(String input) {
    var s = input.replaceAll('-', '+').replaceAll('_', '/');
    final pad = (4 - s.length % 4) % 4;
    s += '=' * pad;
    return base64.decode(s);
  }

  String? _expText() {
    final exp = _claims?['exp'];
    if (exp is! num) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    final expired = t.isBefore(DateTime.now());
    return '${t.toLocal()}（${expired ? "已过期" : "有效"}）';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _controller,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '粘贴 JWT Token',
            hintText: '支持直接粘贴带 Bearer 前缀的 Authorization 值',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _decode,
          icon: const Icon(Icons.key, size: 18),
          label: const Text('解码'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
        if (_header != null) ...[
          const SizedBox(height: 14),
          _section('Header', _header!),
        ],
        if (_payload != null) ...[
          const SizedBox(height: 12),
          _section('Payload', _payload!),
        ],
        if (_expText() != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('过期时间：${_expText()}', style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }

  Widget _section(String title, String body) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: '复制',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: body));
            FlutterToastr.show('已复制', context);
          },
        ),
      ]),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.black45 : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(body,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFFD4D4D4))),
      ),
    ]);
  }
}

// ==================== UUID ====================

class UuidToolPage extends StatefulWidget {
  const UuidToolPage({super.key});

  @override
  State<StatefulWidget> createState() => _UuidToolPageState();
}

class _UuidToolPageState extends State<UuidToolPage> {
  final List<String> _uuids = [];
  final Random _random = Random();
  int _count = 5;
  bool _uppercase = false;

  String _gen() {
    String hex(int n) => List.generate(n, (_) => _random.nextInt(16).toRadixString(16)).join();
    var v = '${hex(8)}-${hex(4)}-4${hex(3)}-${hex(4)}-${hex(12)}';
    return _uppercase ? v.toUpperCase() : v;
  }

  void _generate() {
    setState(() => _uuids
      ..clear()
      ..addAll(List.generate(_count.clamp(1, 50), (_) => _gen())));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(children: [
          const Text('数量', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Slider(
              value: _count.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '$_count',
              onChanged: (v) => setState(() => _count = v.round()),
            ),
          ),
          SwitchWidgetLite(
            value: _uppercase,
            label: '大写',
            onChanged: (v) => setState(() => _uppercase = v),
          ),
        ]),
        FilledButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('生成 UUID v4'),
        ),
        const SizedBox(height: 10),
        if (_uuids.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(child: Text('点击上方按钮生成', style: TextStyle(color: Colors.grey.shade500))),
          )
        else
          ..._uuids.map((u) => Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(u, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                  trailing: const Icon(Icons.copy, size: 16),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: u));
                    FlutterToastr.show('已复制', context);
                  },
                ),
              )),
        if (_uuids.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _uuids.join('\n')));
              FlutterToastr.show('已复制全部', context);
            },
            icon: const Icon(Icons.copy_all, size: 16),
            label: const Text('复制全部'),
          ),
      ],
    );
  }
}

/// 轻量开关（带文字标签）
class SwitchWidgetLite extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const SwitchWidgetLite({super.key, required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13)),
      Switch(value: value, onChanged: onChanged),
    ]);
  }
}

// ==================== SHA 哈希 ====================

class ShaHashPage extends StatefulWidget {
  const ShaHashPage({super.key});

  @override
  State<StatefulWidget> createState() => _ShaHashPageState();
}

class _ShaHashPageState extends State<ShaHashPage> {
  final TextEditingController _controller = TextEditingController();

  Map<String, String> get _hashes {
    final input = utf8.encode(_controller.text);
    return {
      'SHA-1': sha1.convert(input).toString(),
      'SHA-256': sha256.convert(input).toString(),
      'SHA-512': sha512.convert(input).toString(),
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _controller,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '输入文本',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in _hashes.entries) ...[
          Row(children: [
            Text(entry.key,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: '复制',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: entry.value));
                FlutterToastr.show('已复制', context);
              },
            ),
          ]),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.black45 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(entry.value,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 10),
        ],
        Text('以 UTF-8 编码计算；文件/二进制校验请使用抓包数据的十六进制工具。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
