import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/util/logger.dart';
import 'package:proxypin/ui/component/widgets.dart';

/// 配置管理页面 - 导入/导出配置
class ConfigManagement extends StatefulWidget {
  final ProxyServer proxyServer;

  const ConfigManagement({
    super.key,
    required this.proxyServer,
  });

  @override
  State<StatefulWidget> createState() => _ConfigManagementState();
}

class _ConfigManagementState extends State<ConfigManagement> {
  late ProxyServer proxyServer;
  late Configuration configuration;

  @override
  void initState() {
    super.initState();
    proxyServer = widget.proxyServer;
    configuration = widget.proxyServer.configuration;
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
          '配置管理',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          section([
            ListTile(
              leading: const Icon(Icons.file_download, color: Colors.green),
              title: const Text('导出配置'),
              subtitle: const Text('将当前配置导出为 JSON 文件，用于备份或分享'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _exportConfig(context, localizations),
            ),
            Divider(height: 0, thickness: 0.3, color: dividerColor),
            ListTile(
              leading: const Icon(Icons.file_upload, color: Colors.blue),
              title: const Text('导入配置'),
              subtitle: const Text('从 JSON 文件导入配置，会覆盖当前配置'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _importConfig(context, localizations),
            ),
          ]),
          const SizedBox(height: 12),
          Card(
            color: Colors.orange.withValues(alpha: 0.1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '注意事项',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• 导出配置会包含所有代理设置、过滤规则、MCP 配置等\n'
                    '• 导入配置会完全覆盖当前配置，请谨慎操作\n'
                    '• 建议定期导出配置进行备份\n'
                    '• 配置文件为 JSON 格式，可用文本编辑器查看',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 导出配置
  Future<void> _exportConfig(
      BuildContext context, AppLocalizations localizations) async {
    try {
      // 生成默认文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final defaultName = 'proxypin_config_$timestamp.json';

      // 使用 FilePicker 选择保存位置 (v12+ API)
      String? outputPath = await FilePicker.saveFile(
        dialogTitle: '选择保存位置',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputPath == null || outputPath.isEmpty) {
        // 用户取消
        return;
      }

      // 导出配置
      final jsonStr = configuration.exportConfig();
      final file = File(outputPath);
      await file.create(recursive: true);
      await file.writeAsString(jsonStr);

      if (mounted) {
        FlutterToastr.show(
          '配置已导出到：${file.path}',
          context,
          duration: 3,
          backgroundColor: Colors.green,
        );
        logger.i('配置已导出到：$outputPath');
      }
    } catch (e) {
      logger.e('导出配置失败', error: e, stackTrace: StackTrace.current);
      if (mounted) {
        FlutterToastr.show(
          '导出失败：${e.toString()}',
          context,
          duration: 3,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// 导入配置
  Future<void> _importConfig(
      BuildContext context, AppLocalizations localizations) async {
    try {
      // 选择文件 (v12+ API)
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return;
      }

      // 确认导入
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认导入'),
          content: const Text(
            '导入配置会完全覆盖当前配置，确定要继续吗？\n\n建议先导出当前配置进行备份。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      // 导入配置
      final file = File(filePath);
      final jsonStr = await file.readAsString();
      final newConfig = await ConfigImportExport.importConfig(jsonStr);

      // 应用新配置
      configuration.port = newConfig.port;
      configuration.enableSsl = newConfig.enableSsl;
      configuration.startup = newConfig.startup;
      configuration.enableSystemProxy = newConfig.enableSystemProxy;
      configuration.enableSocks5 = newConfig.enableSocks5;
      configuration.proxyPassDomains = newConfig.proxyPassDomains;
      configuration.externalProxy = newConfig.externalProxy;
      configuration.appWhitelist = newConfig.appWhitelist;
      configuration.appWhitelistEnabled = newConfig.appWhitelistEnabled;
      configuration.appBlacklist = newConfig.appBlacklist;
      configuration.historyCacheTime = newConfig.historyCacheTime;
      configuration.mcpPort = newConfig.mcpPort;
      configuration.mcpEnabled = newConfig.mcpEnabled;
      configuration.mcpAutoStart = newConfig.mcpAutoStart;
      configuration.mcpToolsEnabled = newConfig.mcpToolsEnabled;
      configuration.enabledHttp2 = newConfig.enabledHttp2;

      // 刷新配置
      configuration.flushConfig();

      if (mounted) {
        FlutterToastr.show(
          '配置导入成功，部分设置可能需要重启应用后生效',
          context,
          duration: 3,
          backgroundColor: Colors.green,
        );
        logger.i('配置已从 $filePath 导入成功');

        // 刷新页面显示
        setState(() {});
      }
    } catch (e) {
      logger.e('导入配置失败', error: e, stackTrace: StackTrace.current);
      if (mounted) {
        FlutterToastr.show(
          '导入失败：${e.toString()}',
          context,
          duration: 3,
          backgroundColor: Colors.red,
        );
      }
    }
  }
}
