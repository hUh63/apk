import 'package:flutter/material.dart';
import '../../network/http/connection_pool.dart';

/// 性能监控仪表盘 - 显示连接池和请求性能统计
class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({super.key});

  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard> {
  bool _isRefreshing = false;
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // 每 2 秒自动刷新一次
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _lastUpdateTime = DateTime.now();
        });
        _startAutoRefresh();
      }
    });
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _isRefreshing = false;
      _lastUpdateTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('性能监控'),
          actions: [
            IconButton(
              icon: Icon(_isRefreshing ? Icons.refresh : Icons.refresh),
              onPressed: _isRefreshing ? null : _refresh,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLastUpdateTime(),
              const SizedBox(height: 16),
              _buildPerformanceOverview(),
              const SizedBox(height: 16),
              _buildConnectionPoolStatus(),
              const SizedBox(height: 16),
              _buildPerformanceMetrics(),
              const SizedBox(height: 16),
              _buildRequestStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastUpdateTime() {
    return Text(
      '最后更新：${_lastUpdateTime.hour.toString().padLeft(2, '0')}:${_lastUpdateTime.minute.toString().padLeft(2, '0')}:${_lastUpdateTime.second.toString().padLeft(2, '0')}',
      style: TextStyle(color: Colors.grey[600], fontSize: 12),
    );
  }

  /// 性能概览卡片
  Widget _buildPerformanceOverview() {
    final pool = ConnectionPool.instance;
    final stats = pool.getStats();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text('性能概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[700])),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('总请求', '${stats['totalRequests']}', Colors.blue),
                _buildStatItem('成功', '${stats['successfulRequests']}', Colors.green),
                _buildStatItem('失败', '${stats['failedRequests']}', Colors.red),
                _buildStatItem('成功率', '${stats['successRate'].toStringAsFixed(1)}%', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 连接池状态卡片
  Widget _buildConnectionPoolStatus() {
    final pool = ConnectionPool.instance;
    final stats = pool.getStats();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pool, color: Colors.teal[700]),
                const SizedBox(width: 8),
                Text('连接池状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[700])),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressBar('活跃连接', stats['activeConnections'] as int, stats['maxConnections'] as int, Colors.teal),
            const SizedBox(height: 12),
            _buildProgressBar('空闲连接', stats['idleConnections'] as int, stats['maxConnections'] as int, Colors.green),
            const SizedBox(height: 12),
            _buildProgressBar('等待队列', stats['waitingRequests'] as int, 50, Colors.orange),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('连接复用率:', style: TextStyle(color: Colors.grey[700])),
                Text('${stats['reuseRate'].toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 性能指标卡片
  Widget _buildPerformanceMetrics() {
    final pool = ConnectionPool.instance;
    final stats = pool.getStats();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text('性能指标', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple[700])),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetricRow('平均响应时间', '${(stats['avgResponseTime'] as num).toStringAsFixed(0)}ms'),
            const Divider(height: 24),
            _buildMetricRow('最快响应', '${(stats['minResponseTime'] as num).toStringAsFixed(0)}ms'),
            const Divider(height: 24),
            _buildMetricRow('最慢响应', '${(stats['maxResponseTime'] as num).toStringAsFixed(0)}ms'),
            const Divider(height: 24),
            _buildMetricRow('P95 响应时间', '${(stats['p95ResponseTime'] as num).toStringAsFixed(0)}ms'),
            const Divider(height: 24),
            _buildMetricRow('P99 响应时间', '${(stats['p99ResponseTime'] as num).toStringAsFixed(0)}ms'),
          ],
        ),
      ),
    );
  }

  /// 请求统计卡片
  Widget _buildRequestStats() {
    final pool = ConnectionPool.instance;
    final stats = pool.getStats();
    final breakdown = stats['requestBreakdown'] as Map<String, int>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text('请求统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo[700])),
              ],
            ),
            const SizedBox(height: 16),
            if (breakdown.isNotEmpty) ...[
              ...breakdown.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: TextStyle(color: Colors.grey[700])),
                    Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
            ] else ...[
              Center(
                child: Text('暂无数据', style: TextStyle(color: Colors.grey[400])),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, MaterialColor color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color[700])),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildProgressBar(String label, int current, int max, MaterialColor color) {
    final percent = max > 0 ? current / max : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            Text('$current / $max', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            backgroundColor: color[100],
            valueColor: AlwaysStoppedAnimation<Color>(color[700]!),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
