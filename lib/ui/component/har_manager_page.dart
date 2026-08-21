/*
 * HAR 文件管理页面 - 导入导出 HAR 文件
 * 支持查看、分享、删除 HAR 文件
 */

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:proxypin/utils/har.dart';
import 'package:proxypin/l10n/app_localizations.dart';

/// HAR 文件条目
class HarFileEntry {
  final String name;
  final String path;
  final int size;
  final DateTime createdAt;
  final int requestCount;

  HarFileEntry({
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.requestCount,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}

/// HAR 文件管理页面
class HarManagerPage extends StatefulWidget {
  const HarManagerPage({super.key});

  @override
  State<HarManagerPage> createState() => _HarManagerPageState();
}

class _HarManagerPageState extends State<HarManagerPage> {
  List<HarFileEntry> _harFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHarFiles();
  }

  Future<void> _loadHarFiles() async {
    setState(() => _isLoading = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final harDir = Directory('${directory.path}/har');
      
      if (!await harDir.exists()) {
        await harDir.create(recursive: true);
      }

      final files = await harDir.list().toList();
      final entries = <HarFileEntry>[];

      for (final file in files) {
        if (file is File && file.path.endsWith('.har')) {
          final stat = await file.stat();
          // 解析 HAR 文件获取请求数量
          int requestCount = 0;
          try {
            final content = await file.readAsString();
            // 简单统计请求数量
            requestCount = content.split('"_id":').length - 1;
          } catch (e) {
            // 忽略解析错误
          }

          entries.add(HarFileEntry(
            name: file.uri.pathSegments.last,
            path: file.path,
            size: stat.size,
            createdAt: stat.modified,
            requestCount: requestCount,
          ));
        }
      }

      // 按创建时间排序
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _harFiles = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：$e')),
        );
      }
    }
  }

  Future<void> _importHar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['har'],
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        final fileName = result.files.single.name;

        // 复制到应用目录
        final directory = await getApplicationDocumentsDirectory();
        final harDir = Directory('${directory.path}/har');
        
        if (!await harDir.exists()) {
          await harDir.create(recursive: true);
        }

        final destPath = '${harDir.path}/$fileName';
        await File(sourcePath).copy(destPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('HAR 文件导入成功')),
          );
          _loadHarFiles();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    }
  }

  Future<void> _exportHar(HarFileEntry entry) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(entry.path)],
        subject: entry.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.status == ShareResultStatus.success 
                ? '导出成功' 
                : '导出失败'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    }
  }

  Future<void> _deleteHar(HarFileEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定要删除 ${entry.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await File(entry.path).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件已删除')),
          );
          _loadHarFiles();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败：$e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HAR 管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHarFiles,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _importHar,
            tooltip: '导入 HAR',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _harFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无 HAR 文件',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击右上角导入或导出抓包数据',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _importHar,
                        icon: const Icon(Icons.download),
                        label: const Text('导入 HAR 文件'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _harFiles.length,
                  itemBuilder: (context, index) {
                    final entry = _harFiles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: Colors.orange,
                          ),
                        ),
                        title: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${entry.formattedSize} • ${entry.requestCount} 个请求',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              entry.formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'export':
                                _exportHar(entry);
                                break;
                              case 'delete':
                                _deleteHar(entry);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'export',
                              child: ListTile(
                                leading: Icon(Icons.share),
                                title: Text('导出'),
                                dense: true,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text('删除', style: TextStyle(color: Colors.red)),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _showHarDetail(entry),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // 导出当前抓包数据为 HAR
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在导出当前抓包数据...')),
          );
          // 这里调用 HAR 导出功能
        },
        icon: const Icon(Icons.save),
        label: const Text('导出当前'),
      ),
    );
  }

  void _showHarDetail(HarFileEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAR 文件详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('文件名', entry.name),
            _buildDetailRow('文件大小', entry.formattedSize),
            _buildDetailRow('请求数量', '${entry.requestCount} 个'),
            _buildDetailRow('创建时间', entry.formattedDate),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportHar(entry);
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
