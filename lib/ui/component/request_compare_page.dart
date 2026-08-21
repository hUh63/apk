/*
 * 请求对比分析页面 - 详细的请求差异对比
 */

import 'package:flutter/material.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/util/request_comparator.dart';

/// 请求对比页面
class RequestComparePage extends StatefulWidget {
  final Request requestA;
  final Request requestB;
  final Response? responseA;
  final Response? responseB;

  const RequestComparePage({
    super.key,
    required this.requestA,
    required this.requestB,
    this.responseA,
    this.responseB,
  });

  @override
  State<RequestComparePage> createState() => _RequestComparePageState();
}

class _RequestComparePageState extends State<RequestComparePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ComparisonResult _result;
  final RequestComparator _comparator = RequestComparator();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _result = _comparator.compare(
      widget.requestA,
      widget.requestB,
      responseA: widget.responseA,
      responseB: widget.responseB,
    );
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
        title: Text('请求对比'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '请求头'),
            Tab(text: '请求体'),
            Tab(text: '响应'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildHeadersTab(),
          _buildBodyTab(),
          _buildResponseTab(),
        ],
      ),
    );
  }

  /// 概览标签页
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 对比结果卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    _result.hasChanges ? Icons.warning_amber : Icons.check_circle,
                    size: 64,
                    color: _result.hasChanges ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _result.hasChanges ? '存在差异' : '完全相同',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _result.hasChanges ? Colors.orange : Colors.green,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '共 ${_result.totalChanges} 处变化',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // URL 对比
          _buildComparisonCard(
            'URL',
            widget.requestA.url,
            widget.requestB.url,
            changed: _result.urlChanged,
          ),

          const SizedBox(height: 12),

          // 方法对比
          _buildComparisonCard(
            '方法',
            widget.requestA.method,
            widget.requestB.method,
            changed: _result.methodChanged,
          ),

          const SizedBox(height: 12),

          // 统计信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '变化统计',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow('请求头变化', _result.headerDiffs.length),
                  _buildStatRow('参数变化', _result.queryDiffs.length),
                  _buildStatRow('请求体变化', _result.bodyDiff?.hasChanged ?? false ? 1 : 0),
                  if (_result.statusCodeChanged)
                    _buildStatRow('状态码变化', 1),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 详细报告
          Card(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '详细报告',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _result.detailedReport,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
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

  /// 请求头对比标签页
  Widget _buildHeadersTab() {
    if (_result.headerDiffs.isEmpty) {
      return const Center(
        child: Text('请求头无变化'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _result.headerDiffs.length,
      itemBuilder: (context, index) {
        final diff = _result.headerDiffs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _getChangeTypeIcon(diff.type),
            title: Text(diff.fieldName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diff.oldValue != null)
                  Text(
                    '旧：${diff.oldValue}',
                    style: TextStyle(
                      color: diff.type == CompareType.removed ? Colors.red : null,
                    ),
                  ),
                if (diff.newValue != null)
                  Text(
                    '新：${diff.newValue}',
                    style: TextStyle(
                      color: diff.type == CompareType.added ? Colors.green : null,
                    ),
                  ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  /// 请求体对比标签页
  Widget _buildBodyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_result.bodyDiff == null || !_result.bodyDiff!.hasChanged)
            const Center(
              child: Text('请求体无变化'),
            )
          else
            Column(
              children: [
                _buildCodeDiff(
                  '请求体 A',
                  widget.requestA.body,
                  '请求体 B',
                  widget.requestB.body,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 响应标签页
  Widget _buildResponseTab() {
    if (widget.responseA == null && widget.responseB == null) {
      return const Center(
        child: Text('无响应数据'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态码对比
          if (widget.responseA != null && widget.responseB != null)
            _buildComparisonCard(
              '状态码',
              '${widget.responseA!.statusCode}',
              '${widget.responseB!.statusCode}',
              changed: _result.statusCodeChanged,
            ),

          const SizedBox(height: 16),

          // 响应头对比
          Text(
            '响应头变化 (${_result.responseHeaderDiffs.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_result.responseHeaderDiffs.isEmpty)
            const Text('无变化')
          else
            ..._result.responseHeaderDiffs.map((diff) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      _getChangeTypeIcon(diff.type, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${diff.fieldName}: ${diff.oldValue ?? ''} → ${diff.newValue ?? ''}'),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(String label, String valueA, String valueB, {required bool changed}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (changed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '已修改',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('请求 A', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 4),
                      SelectableText(
                        valueA,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('请求 B', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 4),
                      SelectableText(
                        valueB,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeDiff(String labelA, String codeA, String labelB, String codeB) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildCodePanel(labelA, codeA),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCodePanel(labelB, codeB),
        ),
      ],
    );
  }

  Widget _buildCodePanel(String label, String code) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code.isEmpty ? '(空)' : code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Chip(
            label: Text('$value'),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _getChangeTypeIcon(CompareType type, {double size = 24}) {
    switch (type) {
      case CompareType.added:
        return Icon(Icons.add_circle, color: Colors.green, size: size);
      case CompareType.removed:
        return Icon(Icons.remove_circle, color: Colors.red, size: size);
      case CompareType.modified:
        return Icon(Icons.edit, color: Colors.orange, size: size);
      case CompareType.unchanged:
        return Icon(Icons.check_circle, color: Colors.grey, size: size);
    }
  }
}

/// 对比工具函数
class RequestCompareUtils {
  static void showCompare(
    BuildContext context,
    Request requestA,
    Request requestB, {
    Response? responseA,
    Response? responseB,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestComparePage(
          requestA: requestA,
          requestB: requestB,
          responseA: responseA,
          responseB: responseB,
        ),
      ),
    );
  }
}
