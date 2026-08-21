/*
 * Copyright 2023 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:convert';
import 'dart:io';
import 'package:proxypin/network/http/http.dart';

/// 批量操作结果
class BatchOperationResult {
  final int total;
  final int success;
  final int failed;
  final List<String> errors;

  BatchOperationResult({
    required this.total,
    required this.success,
    required this.failed,
    this.errors = const [],
  });

  double get successRate => total > 0 ? (success / total * 100) : 0;

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'success': success,
      'failed': failed,
      'successRate': successRate,
      'errors': errors,
    };
  }
}

/// 批量操作统计信息
class BatchStatistics {
  final int totalRequests;
  final int selectedRequests;
  final int totalSize;
  final Map<String, int> methodCounts;
  final Map<String, int> domainCounts;
  final DateTimeRange? timeRange;

  BatchStatistics({
    required this.totalRequests,
    required this.selectedRequests,
    required this.totalSize,
    required this.methodCounts,
    required this.domainCounts,
    this.timeRange,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalRequests': totalRequests,
      'selectedRequests': selectedRequests,
      'totalSize': totalSize,
      'methodCounts': methodCounts,
      'domainCounts': domainCounts,
      'timeRange': timeRange != null
          ? {
              'start': timeRange!.start.toIso8601String(),
              'end': timeRange!.end.toIso8601String(),
            }
          : null,
    };
  }
}

/// 请求批量操作管理器 (Feature 6)
class BatchOperationsManager {
  static final BatchOperationsManager _instance =
      BatchOperationsManager._internal();
  factory BatchOperationsManager() => _instance;
  BatchOperationsManager._internal();

  /// 批量删除请求
  /// [requests] 要删除的请求列表
  /// [filter] 可选过滤器，如果提供则只删除匹配的请求
  Future<BatchOperationResult> batchDelete(
    List<HttpRequest> requests, {
    RequestFilter? filter,
  }) async {
    int success = 0;
    int failed = 0;
    List<String> errors = [];

    final toDelete = filter != null ? _filterRequests(requests, filter) : requests;

    for (final request in toDelete) {
      try {
        // 标记请求为已删除 (实际删除由上层 UI 处理)
        request.isDeleted = true;
        success++;
      } catch (e) {
        failed++;
        errors.add('删除失败 ${request.id}: $e');
      }
    }

    return BatchOperationResult(
      total: toDelete.length,
      success: success,
      failed: failed,
      errors: errors,
    );
  }

  /// 批量导出请求为 HAR 格式
  Future<BatchOperationResult> batchExportHar(
    List<HttpRequest> requests, {
    required String outputPath,
    RequestFilter? filter,
  }) async {
    int success = 0;
    int failed = 0;
    List<String> errors = [];

    final toExport = filter != null ? _filterRequests(requests, filter) : requests;

    try {
      // 构建 HAR 数据结构
      final har = {
        'log': {
          'version': '1.2',
          'creator': {
            'name': 'ProxyPin',
            'version': '1.9.0',
          },
          'entries': toExport.map((req) => _requestToHarEntry(req)).toList(),
        },
      };

      // 写入文件
      final file = File(outputPath);
      await file.writeAsString(jsonEncode(har), flush: true);
      success = toExport.length;
    } catch (e) {
      failed = toExport.length;
      errors.add('导出失败：$e');
    }

    return BatchOperationResult(
      total: toExport.length,
      success: success,
      failed: failed,
      errors: errors,
    );
  }

  /// 批量导出请求为 JSON
  Future<BatchOperationResult> batchExportJson(
    List<HttpRequest> requests, {
    required String outputPath,
    RequestFilter? filter,
  }) async {
    int success = 0;
    int failed = 0;
    List<String> errors = [];

    final toExport = filter != null ? _filterRequests(requests, filter) : requests;

    try {
      final jsonData = toExport.map((req) => req.toJson()).toList();
      final file = File(outputPath);
      await file.writeAsString(jsonEncode(jsonData), flush: true);
      success = toExport.length;
    } catch (e) {
      failed = toExport.length;
      errors.add('导出失败：$e');
    }

    return BatchOperationResult(
      total: toExport.length,
      success: success,
      failed: failed,
      errors: errors,
    );
  }

  /// 批量修改请求头
  Future<BatchOperationResult> batchModifyHeaders(
    List<HttpRequest> requests, {
    required Map<String, String> headers,
    bool overwrite = false,
    RequestFilter? filter,
  }) async {
    int success = 0;
    int failed = 0;
    List<String> errors = [];

    final toModify = filter != null ? _filterRequests(requests, filter) : requests;

    for (final request in toModify) {
      try {
        for (final entry in headers.entries) {
          if (overwrite || !request.headers.containsKey(entry.key)) {
            request.headers[entry.key] = entry.value;
          }
        }
        success++;
      } catch (e) {
        failed++;
        errors.add('修改失败 ${request.id}: $e');
      }
    }

    return BatchOperationResult(
      total: toModify.length,
      success: success,
      failed: failed,
      errors: errors,
    );
  }

  /// 批量重放请求
  Future<BatchOperationResult> batchReplay(
    List<HttpRequest> requests, {
    RequestFilter? filter,
    Function(HttpRequest, bool)? onReplay,
  }) async {
    int success = 0;
    int failed = 0;
    List<String> errors = [];

    final toReplay = filter != null ? _filterRequests(requests, filter) : requests;

    for (final request in toReplay) {
      try {
        // 创建新的 HTTP 客户端并发送请求
        final client = HttpClient();
        try {
          final uri = Uri.parse(request.requestUrl ?? '');
          var httpRequest = await client.openUrl(request.method ?? 'GET', uri);

          // 复制请求头
          request.headers.forEach((key, value) {
            httpRequest.headers.set(key, value);
          });

          // 复制请求体
          if (request.body != null && request.body!.isNotEmpty) {
            httpRequest.write(request.body);
          }

          final response = await httpRequest.close();
          success++;
          onReplay?.call(request, true);
        } finally {
          client.close();
        }
      } catch (e) {
        failed++;
        errors.add('重放失败 ${request.id}: $e');
        onReplay?.call(request, false);
      }
    }

    return BatchOperationResult(
      total: toReplay.length,
      success: success,
      failed: failed,
      errors: errors,
    );
  }

  /// 批量删除请求体 (减小内存占用)
  Future<BatchOperationResult> batchClearBodies(
    List<HttpRequest> requests, {
    RequestFilter? filter,
  }) async {
    int success = 0;
    int failed = 0;
    List<String> errors = [];

    final toClear = filter != null ? _filterRequests(requests, filter) : requests;

    for (final request in toClear) {
      try {
        request.body = null;
        request.responseBody = null;
        success++;
      } catch (e) {
        failed++;
        errors.add('清除失败 ${request.id}: $e');
      }
    }

    return BatchOperationResult(
      total: toClear.length,
      success: success,
      failed: failed,
      errors: errors,
    );
  }

  /// 获取批量统计信息
  BatchStatistics getStatistics(
    List<HttpRequest> requests, {
    List<String>? selectedIds,
  }) {
    final selected = selectedIds != null
        ? requests.where((r) => selectedIds.contains(r.id)).toList()
        : requests;

    final methodCounts = <String, int>{};
    final domainCounts = <String, int>{};
    int totalSize = 0;
    DateTime? minTime;
    DateTime? maxTime;

    for (final request in selected) {
      // 统计方法
      final method = request.method ?? 'UNKNOWN';
      methodCounts[method] = (methodCounts[method] ?? 0) + 1;

      // 统计域名
      try {
        final uri = Uri.parse(request.requestUrl ?? '');
        final domain = uri.host;
        if (domain.isNotEmpty) {
          domainCounts[domain] = (domainCounts[domain] ?? 0) + 1;
        }
      } catch (e) {
        // 忽略解析失败的 URL
      }

      // 计算大小
      totalSize += request.contentLength ?? 0;
      totalSize += request.responseContentLength ?? 0;

      // 时间范围
      final time = request.time;
      if (time != null) {
        if (minTime == null || time.isBefore(minTime)) {
          minTime = time;
        }
        if (maxTime == null || time.isAfter(maxTime)) {
          maxTime = time;
        }
      }
    }

    return BatchStatistics(
      totalRequests: requests.length,
      selectedRequests: selected.length,
      totalSize: totalSize,
      methodCounts: methodCounts,
      domainCounts: domainCounts,
      timeRange: minTime != null && maxTime != null
          ? DateTimeRange(start: minTime, end: maxTime)
          : null,
    );
  }

  /// 过滤器
  List<HttpRequest> _filterRequests(
    List<HttpRequest> requests,
    RequestFilter filter,
  ) {
    return requests.where((r) {
      if (filter.urlPattern != null &&
          !(r.requestUrl?.contains(filter.urlPattern!) ?? false)) {
        return false;
      }
      if (filter.methods != null &&
          !filter.methods!.contains(r.method ?? '')) {
        return false;
      }
      if (filter.statusCode != null &&
          r.responseStatusCode != filter.statusCode) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 将请求转换为 HAR 条目
  Map<String, dynamic> _requestToHarEntry(HttpRequest request) {
    return {
      'startedDateTime': request.time?.toIso8601String() ?? '',
      'time': request.duration ?? 0,
      'request': {
        'method': request.method ?? 'GET',
        'url': request.requestUrl ?? '',
        'httpVersion': 'HTTP/1.1',
        'headers': request.headers.entries
            .map((e) => {'name': e.key, 'value': e.value})
            .toList(),
        'queryString': [],
        'bodySize': request.contentLength ?? 0,
      },
      'response': {
        'status': request.responseStatusCode ?? 0,
        'statusText': request.responseStatusText ?? '',
        'httpVersion': 'HTTP/1.1',
        'headers': request.responseHeaders?.entries
                .map((e) => {'name': e.key, 'value': e.value})
                .toList() ??
            [],
        'bodySize': request.responseContentLength ?? 0,
      },
      'cache': {},
      'timings': {
        'send': 0,
        'wait': request.duration ?? 0,
        'receive': 0,
      },
    };
  }
}

/// 请求过滤器
class RequestFilter {
  final String? urlPattern;
  final List<String>? methods;
  final int? statusCode;
  final DateTime? startTime;
  final DateTime? endTime;

  RequestFilter({
    this.urlPattern,
    this.methods,
    this.statusCode,
    this.startTime,
    this.endTime,
  });

  RequestFilter copyWith({
    String? urlPattern,
    List<String>? methods,
    int? statusCode,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return RequestFilter(
      urlPattern: urlPattern ?? this.urlPattern,
      methods: methods ?? this.methods,
      statusCode: statusCode ?? this.statusCode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
