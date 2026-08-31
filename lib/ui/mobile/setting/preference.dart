import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/native/vpn.dart';
import 'package:proxypin/network/util/mtls.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/util/logger.dart';
import 'package:proxypin/storage/path.dart';
import 'package:proxypin/ui/component/widgets.dart';
import 'package:proxypin/ui/configuration.dart';
import 'package:proxypin/ui/mobile/setting/config_management.dart';
import 'package:proxypin/ui/mobile/setting/theme.dart';

///设置
///@author wanghongen
class Preference extends StatefulWidget {
  final ProxyServer proxyServer;
  final AppConfiguration appConfiguration;

  const Preference({
    super.key,
    required this.proxyServer,
    required this.appConfiguration,
  });

  @override
  State<StatefulWidget> createState() => _PreferenceState();
}

class _PreferenceState extends State<Preference> {
  late ProxyServer proxyServer;
  late Configuration configuration;
  late AppConfiguration appConfiguration;

  final memoryCleanupController = TextEditingController();
  final memoryCleanupList = [null, 512, 1024, 2048, 4096];

  /// 已拦截的 QUIC 包数（Android VPN 层上报）
  int _quicCount = 0;

  @override
  void initState() {
    super.initState();
    proxyServer = widget.proxyServer;
    configuration = widget.proxyServer.configuration;
    appConfiguration = widget.appConfiguration;

    if (!memoryCleanupList.contains(appConfiguration.memoryCleanupThreshold)) {
      memoryCleanupController.text = appConfiguration.memoryCleanupThreshold
          .toString();
    }
    _loadQuicCount();
  }

  Future<void> _loadQuicCount() async {
    if (!Platform.isAndroid) return;
    try {
      final count = await Vpn.quicBlockedCount();
      if (mounted && count != _quicCount) {
        setState(() => _quicCount = count);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    memoryCleanupController.dispose();
    super.dispose();
  }

  /// 启动页设置区块：开关 / 背景（原启动页·渐变·自定义图片·透明）/ 时长 / 自定义小字
  Widget _buildSplashSection(Color dividerColor) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        ListTile(
          title: const Text('启动页'),
          subtitle: const Text('默认使用系统原生启动页，可切换为自定义品牌页', style: TextStyle(fontSize: 12)),
          trailing: SwitchWidget(
            value: appConfiguration.splashEnabled,
            scale: 0.8,
            onChanged: (value) {
              setState(() => appConfiguration.splashEnabled = value);
              appConfiguration.flushConfig();
            },
          ),
        ),
        // 背景模式始终可见，便于直接切换
        Divider(height: 0, thickness: 0.3, color: dividerColor),
        ListTile(
          title: const Text('背景'),
          trailing: DropdownButton<String>(
            value: appConfiguration.splashBackground,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'off', child: Text('原启动页（默认）')),
              DropdownMenuItem(value: 'gradient', child: Text('渐变品牌页')),
              DropdownMenuItem(value: 'custom', child: Text('自定义图片')),
              DropdownMenuItem(value: 'transparent', child: Text('透明（跟随主题）')),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == 'custom' && appConfiguration.splashBackgroundPath == null) {
                // 首次切换到自定义图片时立即选图
                _pickSplashBackground();
                return;
              }
              setState(() => appConfiguration.splashBackground = v);
              appConfiguration.flushConfig();
            },
          ),
        ),
        // 选择自定义品牌页后展示详细设置
        if (appConfiguration.splashEnabled && appConfiguration.splashBackground != 'off') ...[
          Divider(height: 0, thickness: 0.3, color: dividerColor),
          ListTile(
            title: const Text('展示时长'),
            subtitle: Text(
              '${(appConfiguration.splashDurationMs / 1000).toStringAsFixed(1)} 秒',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: appConfiguration.splashDurationMs.toDouble(),
                min: 500,
                max: 5000,
                divisions: 9,
                label: '${(appConfiguration.splashDurationMs / 1000).toStringAsFixed(1)}s',
                onChanged: (v) {
                  setState(() => appConfiguration.splashDurationMs = v.round());
                  appConfiguration.flushConfig();
                },
              ),
            ),
          ),
          if (appConfiguration.splashBackground == 'custom') ...[
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            ListTile(
              title: const Text('自定义图片'),
              subtitle: Text(
                appConfiguration.splashBackgroundPath == null ? '未选择' : '已设置，点击更换',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.image_outlined, size: 20),
              onTap: _pickSplashBackground,
            ),
          ],
          Divider(height: 0, thickness: 0.3, color: dividerColor),
          ListTile(
            title: const Text('自定义小字'),
            subtitle: Text(
              appConfiguration.splashSubtitle?.isNotEmpty == true
                  ? appConfiguration.splashSubtitle!
                  : '默认显示版本信息',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: _editSplashSubtitle,
          ),
        ],
      ]),
    );
  }

  /// 选择启动页自定义背景图片，并复制到应用目录持久化
  Future<void> _pickSplashBackground() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      // 复制到应用目录，避免缓存路径失效
      final source = File(file.path!);
      final ext = file.path!.split('.').last.toLowerCase();
      final target = await Paths.getPath('splash_bg.$ext');
      await source.copy(target.path);
      setState(() {
        appConfiguration.splashBackgroundPath = target.path;
        appConfiguration.splashBackground = 'custom';
      });
      appConfiguration.flushConfig();
    } catch (e) {
      logger.e('选择启动页背景失败', error: e);
    }
  }

  /// 编辑启动页自定义小字
  Future<void> _editSplashSubtitle() async {
    final controller = TextEditingController(text: appConfiguration.splashSubtitle ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义小字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: '副标题文本',
            hintText: '留空恢复默认（显示版本信息）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => appConfiguration.splashSubtitle = result.isEmpty ? null : result);
    appConfiguration.flushConfig();
  }

  /// mTLS 证书配置弹窗：选择证书链与私钥（PEM），启用后对新连接生效
  Future<bool> _showMtlsDialog() async {
    final chainController = TextEditingController(text: configuration.mtlsChainPath ?? '');
    final keyController = TextEditingController(text: configuration.mtlsKeyPath ?? '');
    var loading = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('双向认证 (mTLS)', style: TextStyle(fontSize: 16)),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: chainController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '客户端证书链 (PEM)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    onPressed: () async {
                      final file = await FilePicker.pickFile(type: FileType.any);
                      if (file?.path != null) {
                        final saved = await Mtls.persist(file!.path!, 'mtls_chain.pem');
                        chainController.text = saved;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keyController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '客户端私钥 (PEM，未加密)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    onPressed: () async {
                      final file = await FilePicker.pickFile(type: FileType.any);
                      if (file?.path != null) {
                        final saved = await Mtls.persist(file!.path!, 'mtls_key.pem');
                        keyController.text = saved;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '证书链包含 -----BEGIN CERTIFICATE-----，私钥包含 -----BEGIN PRIVATE KEY-----（不支持加密私钥）。配置后对新建立的 HTTPS 连接生效。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final chain = chainController.text.trim();
                final key = keyController.text.trim();
                if (chain.isEmpty || key.isEmpty) {
                  FlutterToastr.show('请先选择证书链与私钥文件', context, backgroundColor: Colors.orange);
                  return;
                }
                if (!Mtls.looksLikePem(chain, 'CERTIFICATE')) {
                  FlutterToastr.show('证书链文件格式不正确（需要 PEM）', context, backgroundColor: Colors.red);
                  return;
                }
                if (!Mtls.looksLikePem(key, 'PRIVATE KEY') && !Mtls.looksLikePem(key, 'EC PRIVATE KEY') &&
                    !Mtls.looksLikePem(key, 'RSA PRIVATE KEY')) {
                  FlutterToastr.show('私钥文件格式不正确（需要未加密 PEM）', context, backgroundColor: Colors.red);
                  return;
                }
                setState(() => loading = true);
                final ok = await Mtls.load(chain, key);
                if (!ok) {
                  setState(() => loading = false);
                  if (context.mounted) {
                    FlutterToastr.show('证书加载失败，请检查文件内容', context, backgroundColor: Colors.red);
                  }
                  return;
                }
                configuration.mtlsChainPath = chain;
                configuration.mtlsKeyPath = key;
                configuration.mtlsEnabled = true;
                configuration.flushConfig();
                if (context.mounted) Navigator.pop(context, true);
              },
              child: loading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('启用'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      FlutterToastr.show('mTLS 已启用', context, backgroundColor: Colors.green);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    final borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.13);
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.22);

    Widget section(List<Widget> tiles) => Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: tiles),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.preference,
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          section([
            ListTile(
              title: Text(localizations.language),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _language(context),
            ),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            MobileThemeSetting(appConfiguration: appConfiguration),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            ListTile(title: Text(localizations.themeColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: themeColor(context),
            ),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            ListTile(
              title: const Text('莫奈取色'),
              subtitle: const Text(
                'Android 12+ 跟随壁纸配色（主题与启动页自动取色）',
                style: TextStyle(fontSize: 12),
              ),
              trailing: SwitchWidget(
                value: appConfiguration.monetEnabled,
                scale: 0.8,
                onChanged: (value) {
                  setState(() => appConfiguration.monetEnabled = value);
                  appConfiguration.flushConfig();
                  // 触发 MaterialApp 重建，莫奈取色立即生效
                  appConfiguration.globalChange.value = !appConfiguration.globalChange.value;
                },
              ),
            ),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            if (Platform.isAndroid) ...[
              ListTile(
                title: const Text('拦截 QUIC (UDP:443)'),
                subtitle: Text(
                  _quicCount > 0
                      ? '已拦截 $_quicCount 个 QUIC 包，强制回落 TCP 使流量可抓包'
                      : '丢弃 UDP 443 强制应用回落 TCP，使 HTTPS 流量可抓包',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: SwitchWidget(
                  value: configuration.blockQuic,
                  scale: 0.8,
                  onChanged: (value) {
                    setState(() => configuration.blockQuic = value);
                    configuration.flushConfig();
                    if (!value) {
                      FlutterToastr.show('已关闭，重新启动抓包后生效', context);
                    }
                  },
                ),
              ),
            ],
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            ListTile(
              title: const Text('双向认证 (mTLS)'),
              subtitle: Text(
                configuration.mtlsEnabled
                    ? '已启用 · 点击配置客户端证书'
                    : '与上游服务器 TLS 握手时提供客户端证书（PEM）',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: SwitchWidget(
                value: configuration.mtlsEnabled,
                scale: 0.8,
                onChanged: (value) async {
                  if (value) {
                    final ok = await _showMtlsDialog();
                    if (!ok) return;
                  } else {
                    Mtls.unload();
                    setState(() => configuration.mtlsEnabled = false);
                    configuration.flushConfig();
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _buildSplashSection(dividerColor),
          const SizedBox(height: 12),
          section([
            ListTile(
              title: Text(localizations.autoStartup),
              subtitle: Text(
                localizations.autoStartupDescribe,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: SwitchWidget(
                value: proxyServer.configuration.startup,
                scale: 0.8,
                onChanged: (value) {
                  configuration.startup = value;
                  configuration.flushConfig();
                },
              ),
            ),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            if (Platform.isAndroid) ...[
              ListTile(
                title: Text(localizations.windowMode),
                subtitle: Text(
                  localizations.windowModeSubTitle,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: SwitchWidget(
                  value: appConfiguration.pipEnabled.value,
                  scale: 0.8,
                  onChanged: (value) {
                    appConfiguration.pipEnabled.value = value;
                    appConfiguration.flushConfig();
                  },
                ),
              ),
              Divider(height: 0, thickness: 0.3, color: dividerColor),
            ],
            ListTile(
              title: Text(localizations.pipIcon),
              subtitle: Text(
                localizations.pipIconDescribe,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: SwitchWidget(
                value: appConfiguration.pipIcon.value,
                scale: 0.8,
                onChanged: (value) {
                  appConfiguration.pipIcon.value = value;
                  appConfiguration.flushConfig();
                },
              ),
            ),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            ListTile(
              title: Text(localizations.bottomNavigation),
              subtitle: Text(
                localizations.bottomNavigationSubtitle,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: SwitchWidget(
                value: appConfiguration.bottomNavigation,
                scale: 0.8,
                onChanged: (value) {
                  appConfiguration.bottomNavigation = value;
                  appConfiguration.flushConfig();
                },
              ),
            ),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            ListTile(
              title: Text(localizations.clearConfirm),
              subtitle: Text(
                localizations.clearConfirmSubtitle,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: SwitchWidget(
                value: appConfiguration.clearConfirm,
                scale: 0.8,
                onChanged: (value) {
                  appConfiguration.clearConfirm = value;
                  appConfiguration.flushConfig();
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          section([
            ListTile(
              title: Text(localizations.memoryCleanup),
              subtitle: Text(
                localizations.memoryCleanupSubtitle,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: memoryCleanup(context, localizations),
            ),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            ListTile(
              title: Text(localizations.maxRequestCount),
              subtitle: Text(
                localizations.maxRequestCountSubtitle,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: maxRequestCount(context, localizations),
            ),
          ]),
          const SizedBox(height: 12),
          // 配置管理区块
          section([
            ListTile(
              leading: const Icon(Icons.settings_backup_restore, color: Colors.blue),
              title: const Text('配置管理'),
              subtitle: const Text('导入/导出配置，备份或恢复设置'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfigManagement(proxyServer: proxyServer),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget themeColor(BuildContext context) {
    return Wrap(
      children: ColorMapping.colors.entries.map((pair) {
        var dividerColor = Theme.of(context).focusColor;
        var background = appConfiguration.themeColor == pair.value
            ? dividerColor
            : Colors.transparent;

        return GestureDetector(
          onTap: () => appConfiguration.setThemeColor = pair.key,
          child: Tooltip(
            message: pair.key,
            child: Container(
              margin: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: Colors.transparent, width: 8),
              ),
              child: Dot(color: pair.value, size: 15),
            ),
          ),
        );
      }).toList(),
    );
  }

  //选择语言
  void _language(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(left: 5, top: 5),
          actionsPadding: const EdgeInsets.only(bottom: 5, right: 5),
          title: Text(
            localizations.language,
            style: const TextStyle(fontSize: 16),
          ),
          content: Wrap(
            children: [
              TextButton(
                onPressed: () {
                  appConfiguration.language = null;
                  Navigator.of(context).pop();
                },
                child: Text(localizations.followSystem),
              ),
              const Divider(thickness: 0.5, height: 0),
              TextButton(
                onPressed: () {
                  appConfiguration.language = const Locale.fromSubtags(
                    languageCode: 'zh',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text("简体中文"),
              ),
              const Divider(thickness: 0.5, height: 0),
              TextButton(
                onPressed: () {
                  appConfiguration.language = const Locale.fromSubtags(
                    languageCode: 'zh',
                    scriptCode: 'Hant',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text("繁體中文"),
              ),
              const Divider(thickness: 0.5, height: 0),
              TextButton(
                onPressed: () {
                  appConfiguration.language = const Locale.fromSubtags(
                    languageCode: 'vi',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text("Tiếng Việt"),
              ),
              const Divider(thickness: 0.5, height: 0),
              TextButton(
                onPressed: () {
                  appConfiguration.language = const Locale.fromSubtags(
                    languageCode: 'th',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text("ไทย"),
              ),
              const Divider(thickness: 0.5, height: 0),
              TextButton(
                onPressed: () {
                  appConfiguration.language = const Locale.fromSubtags(
                    languageCode: 'es',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text("Español"),
              ),
              const Divider(thickness: 0.5, height: 0),
              TextButton(
                child: const Text("English"),
                onPressed: () {
                  appConfiguration.language = const Locale.fromSubtags(
                    languageCode: 'en',
                  );
                  Navigator.of(context).pop();
                },
              ),
              const Divider(thickness: 0.5),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(localizations.cancel),
            ),
          ],
        );
      },
    );
  }

  bool memoryCleanupOpened = false;

  /// 抓包列表最大保留条数选择
  Widget maxRequestCount(BuildContext context, AppLocalizations localizations) {
    final options = [1000, 5000, 10000, 20000, 0];
    return DropdownButton<int>(
      value: appConfiguration.maxRequestCount,
      onChanged: (val) {
        setState(() {
          appConfiguration.maxRequestCount = val ?? 10000;
        });
        appConfiguration.flushConfig();
      },
      underline: Container(),
      items: [
        for (var option in options)
          DropdownMenuItem(
            value: option,
            child: Text(
              option == 0
                  ? localizations.unlimited
                  : option >= 10000
                  ? '${option ~/ 10000}万'
                  : '$option',
            ),
          ),
      ],
    );
  }

  ///内存清理
  Widget memoryCleanup(BuildContext context, AppLocalizations localizations) {
    try {
      return DropdownButton<int>(
        value: appConfiguration.memoryCleanupThreshold,
        onTap: () => memoryCleanupOpened = true,
        onChanged: (val) {
          memoryCleanupOpened = false;
          setState(() {
            appConfiguration.memoryCleanupThreshold = val;
          });
          appConfiguration.flushConfig();
        },
        underline: Container(),
        items: [
          DropdownMenuItem(value: null, child: Text(localizations.unlimited)),
          const DropdownMenuItem(value: 512, child: Text("512M")),
          const DropdownMenuItem(value: 1024, child: Text("1024M")),
          const DropdownMenuItem(value: 2048, child: Text("2048M")),
          const DropdownMenuItem(value: 4096, child: Text("4096M")),
          DropdownMenuInputItem(
            controller: memoryCleanupController,
            child: Container(
              constraints: BoxConstraints(maxWidth: 65, minWidth: 35),
              child: TextField(
                controller: memoryCleanupController,
                keyboardType: TextInputType.datetime,
                onSubmitted: (value) {
                  setState(() {});
                  appConfiguration.memoryCleanupThreshold = int.tryParse(value);
                  appConfiguration.flushConfig();

                  if (memoryCleanupOpened) {
                    memoryCleanupOpened = false;
                    Navigator.pop(context);
                    return;
                  }
                },
                inputFormatters: [
                  LengthLimitingTextInputFormatter(5),
                  FilteringTextInputFormatter.allow(RegExp("[0-9]")),
                ],
                decoration: InputDecoration(
                  hintText: localizations.custom,
                  suffixText: "M",
                ),
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      appConfiguration.memoryCleanupThreshold = null;
      logger.e(
        'memory button build error',
        error: e,
        stackTrace: StackTrace.current,
      );
      return const SizedBox();
    }
  }
}

class DropdownMenuInputItem extends DropdownMenuItem<int> {
  final TextEditingController controller;

  @override
  int? get value => int.tryParse(controller.text) ?? 0;

  const DropdownMenuInputItem({
    super.key,
    required this.controller,
    required super.child,
  });
}
