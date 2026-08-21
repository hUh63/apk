/*
 * 请求对比分析器 - 详细的请求差异对比
 * 支持：URL、Headers、Body、响应 对比
 */

import 'dart:convert';
import 'package:proxypin/network/http/http.dart';

/// 对比结果类型
enum CompareType {
  added,     // 新增
  removed,   // 删除
  modified,  // 修改
  unchanged, // 未变
}

/// 字段对比结果
class FieldCompare {
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final CompareType type;

  FieldCompare({
    required this.fieldName,
    this.oldValue,
    this.newValue,
    this.type = CompareType.unchanged,
  });

  bool get hasChanged => type != CompareType.unchanged;
}

/// 对比结果
class ComparisonResult {
  final Request? requestA;
  final Request? requestB;
  final Response? responseA;
  final Response? responseB;

  // URL 对比
  final String? urlDiff;
  final bool urlChanged;

  // 方法对比
  final bool methodChanged;

  // 请求头对比
  final List<FieldCompare> headerDiffs;

  // 请求体对比
  final FieldCompare? bodyDiff;

  // 查询参数对比
  final List<FieldCompare> queryDiffs;

  // 响应状态码对比
  final bool statusCodeChanged;

  // 响应头对比
  final List<FieldCompare> responseHeaderDiffs;

  // 响应体对比
  final FieldCompare? responseBodyDiff;

  // 总体统计
  final int totalChanges;
  final String summary;

  ComparisonResult({
    this.requestA,
    this.requestB,
    this.responseA,
    this.responseB,
    this.urlDiff,
    this.urlChanged = false,
    this.methodChanged = false,
    this.headerDiffs = const [],
    this.bodyDiff,
    this.queryDiffs = const [],
    this.statusCodeChanged = false,
    this.responseHeaderDiffs = const [],
    this.responseBodyDiff,
    this.totalChanges = 0,
    this.summary = '',
  });

  /// 是否有变化
  bool get hasChanges => totalChanges > 0;

  /// 获取变化详情文本
  String get detailedReport {
    final buffer = StringBuffer();
    buffer.writeln('=== 请求对比报告 ===\n');

    // URL 变化
    if (urlChanged) {
      buffer.writeln('📍 URL 变化:');
      buffer.writeln('  - 旧：$requestA?.url');
      buffer.writeln('  + 新：$requestB?.url\n');
    }

    // 方法变化
    if (methodChanged) {
      buffer.writeln('📝 方法变化:');
      buffer.writeln('  - ${requestA?.method} → + ${requestB?.method}\n');
    }

    // 请求头变化
    if (headerDiffs.isNotEmpty) {
      buffer.writeln('📋 请求头变化 (${headerDiffs.length}):');
      for (var diff in headerDiffs) {
        if (diff.type == CompareType.added) {
          buffer.writeln('  + ${diff.fieldName}: ${diff.newValue}');
        } else if (diff.type == CompareType.removed) {
          buffer.writeln('  - ${diff.fieldName}: ${diff.oldValue}');
        } else if (diff.type == CompareType.modified) {
          buffer.writeln('  ~ ${diff.fieldName}:');
          buffer.writeln('      旧：${diff.oldValue}');
          buffer.writeln('      新：${diff.newValue}');
        }
      }
      buffer.writeln();
    }

    // 请求体变化
    if (bodyDiff != null && bodyDiff!.hasChanged) {
      buffer.writeln('📦 请求体变化:');
      if (bodyDiff!.type == CompareType.modified) {
        buffer.writeln('  旧：${_truncate(bodyDiff!.oldValue, 200)}');
        buffer.writeln('  新：${_truncate(bodyDiff!.newValue, 200)}');
      }
      buffer.writeln();
    }

    // 查询参数变化
    if (queryDiffs.isNotEmpty) {
      buffer.writeln('🔍 查询参数变化 (${queryDiffs.length}):');
      for (var diff in queryDiffs) {
        if (diff.type == CompareType.added) {
          buffer.writeln('  + ${diff.fieldName}=${diff.newValue}');
        } else if (diff.type == CompareType.removed) {
          buffer.writeln('  - ${diff.fieldName}=${diff.oldValue}');
        } else if (diff.type == CompareType.modified) {
          buffer.writeln('  ~ ${diff.fieldName}: ${diff.oldValue} → ${diff.newValue}');
        }
      }
      buffer.writeln();
    }

    // 响应状态码
    if (statusCodeChanged) {
      buffer.writeln('📊 状态码变化:');
      buffer.writeln('  - ${responseA?.statusCode} → + ${responseB?.statusCode}\n');
    }

    // 总结
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('总计变化：$totalChanges 处');
    buffer.writeln('对比结果：${hasChanges ? "存在差异" : "完全相同"}');

    return buffer.toString();
  }

  String _truncate(String? str, int maxLen) {
    if (str == null) return 'null';
    if (str.length <= maxLen) return str;
    return '${str.substring(0, maxLen)}... (${str.length} 字符)';
  }
}

/// 请求对比分析器
class RequestComparator {
  /// 对比两个请求
  ComparisonResult compare(Request requestA, Request requestB, {Response? responseA, Response? responseB}) {
    int changes = 0;
    final headerDiffs = <FieldCompare>[];
    final queryDiffs = <FieldCompare>[];

    // URL 对比
    final urlChanged = requestA.url != requestB.url;
    if (urlChanged) changes++;

    // 方法对比
    final methodChanged = requestA.method != requestB.method;
    if (methodChanged) changes++;

    // 请求头对比
    final allHeaders = <String>{...requestA.headers.keys, ...requestB.headers.keys};
    for (var key in allHeaders) {
      final valueA = requestA.headers[key];
      final valueB = requestB.headers[key];

      if (valueA == null && valueB != null) {
        headerDiffs.add(FieldCompare(fieldName: key, newValue: valueB, type: CompareType.added));
        changes++;
      } else if (valueA != null && valueB == null) {
        headerDiffs.add(FieldCompare(fieldName: key, oldValue: valueA, type: CompareType.removed));
        changes++;
      } else if (valueA != valueB) {
        headerDiffs.add(FieldCompare(fieldName: key, oldValue: valueA, newValue: valueB, type: CompareType.modified));
        changes++;
      }
    }

    // 查询参数对比
    final uriA = Uri.parse(requestA.url);
    final uriB = Uri.parse(requestB.url);
    final allQueryKeys = <String>{...uriA.queryParameters.keys, ...uriB.queryParameters.keys};
    for (var key in allQueryKeys) {
      final valueA = uriA.queryParameters[key];
      final valueB = uriB.queryParameters[key];

      if (valueA == null && valueB != null) {
        queryDiffs.add(FieldCompare(fieldName: key, newValue: valueB, type: CompareType.added));
        changes++;
      } else if (valueA != null && valueB == null) {
        queryDiffs.add(FieldCompare(fieldName: key, oldValue: valueA, type: CompareType.removed));
        changes++;
      } else if (valueA != valueB) {
        queryDiffs.add(FieldCompare(fieldName: key, oldValue: valueA, newValue: valueB, type: CompareType.modified));
        changes++;
      }
    }

    // 请求体对比
    FieldCompare? bodyDiff;
    if (requestA.body != requestB.body) {
      bodyDiff = FieldCompare(
        fieldName: 'body',
        oldValue: requestA.body.isEmpty ? null : requestA.body,
        newValue: requestB.body.isEmpty ? null : requestB.body,
        type: requestA.body.isEmpty ? CompareType.added : (requestB.body.isEmpty ? CompareType.removed : CompareType.modified),
      );
      changes++;
    }

    // 响应状态码对比
    bool statusCodeChanged = false;
    if (responseA != null && responseB != null && responseA.statusCode != responseB.statusCode) {
      statusCodeChanged = true;
      changes++;
    }

    // 响应头对比
    final responseHeaderDiffs = <FieldCompare>[];
    if (responseA != null && responseB != null) {
      final allRespHeaders = <String>{...responseA.headers.keys, ...responseB.headers.keys};
      for (var key in allRespHeaders) {
        final valueA = responseA.headers[key];
        final valueB = responseB.headers[key];

        if (valueA == null && valueB != null) {
          responseHeaderDiffs.add(FieldCompare(fieldName: key, newValue: valueB, type: CompareType.added));
          changes++;
        } else if (valueA != null && valueB == null) {
          responseHeaderDiffs.add(FieldCompare(fieldName: key, oldValue: valueA, type: CompareType.removed));
          changes++;
        } else if (valueA != valueB) {
          responseHeaderDiffs.add(FieldCompare(fieldName: key, oldValue: valueA, newValue: valueB, type: CompareType.modified));
          changes++;
        }
      }
    }

    // 响应体对比
    FieldCompare? responseBodyDiff;
    if (responseA != null && responseB != null && responseA.body != responseB.body) {
      responseBodyDiff = FieldCompare(
        fieldName: 'body',
        oldValue: responseA.body.isEmpty ? null : responseA.body,
        newValue: responseB.body.isEmpty ? null : responseB.body,
        type: responseA.body.isEmpty ? CompareType.added : (responseB.body.isEmpty ? CompareType.removed : CompareType.modified),
      );
      changes++;
    }

    // 生成总结
    final summary = _generateSummary(changes, headerDiffs.length, queryDiffs.length, bodyDiff, urlChanged, methodChanged);

    return ComparisonResult(
      requestA: requestA,
      requestB: requestB,
      responseA: responseA,
      responseB: responseB,
      urlDiff: urlChanged ? '${requestA.url} → ${requestB.url}' : null,
      urlChanged: urlChanged,
      methodChanged: methodChanged,
      headerDiffs: headerDiffs,
      bodyDiff: bodyDiff,
      queryDiffs: queryDiffs,
      statusCodeChanged: statusCodeChanged,
      responseHeaderDiffs: responseHeaderDiffs,
      responseBodyDiff: responseBodyDiff,
      totalChanges: changes,
      summary: summary,
    );
  }

  String _generateSummary(int total, int headers, int queries, FieldCompare? body, bool url, bool method) {
    final parts = <String>[];
    if (url) parts.add('URL 变化');
    if (method) parts.add('方法变化');
    if (headers > 0) parts.add('$headers 个请求头变化');
    if (queries > 0) parts.add('$queries 个参数变化');
    if (body != null && body.hasChanged) parts.add('请求体变化');
    return parts.isEmpty ? '无变化' : parts.join(', ');
  }

  /// 对比两个 JSON 字符串
  String compareJson(String jsonA, String jsonB) {
    try {
      final mapA = json.decode(jsonA) as Map<String, dynamic>;
      final mapB = json.decode(jsonB) as Map<String, dynamic>;
      return _compareMaps(mapA, mapB, '');
    } catch (e) {
      return 'JSON 解析失败：$e';
    }
  }

  String _compareMaps(Map<String, dynamic> a, Map<String, dynamic> b, String prefix) {
    final buffer = StringBuffer();
    final allKeys = <String>{...a.keys, ...b.keys};

    for (var key in allKeys) {
      final valueA = a[key];
      final valueB = b[key];

      if (valueA == null && valueB != null) {
        buffer.writeln('$prefix+ $key: $valueB');
      } else if (valueA != null && valueB == null) {
        buffer.writeln('$prefix- $key: $valueA');
      } else if (valueA is Map && valueB is Map) {
        buffer.write(_compareMaps(valueA as Map<String, dynamic>, valueB as Map<String, dynamic>, '$prefix  '));
      } else if (valueA != valueB) {
        buffer.writeln('$prefix~ $key: $valueA → $valueB');
      }
    }

    return buffer.toString();
  }

  /// 并排对比视图数据
  Map<String, dynamic> getSideBySideView(ComparisonResult result) {
    return {
      'url': {
        'left': result.requestA?.url ?? '',
        'right': result.requestB?.url ?? '',
        'changed': result.urlChanged,
      },
      'method': {
        'left': result.requestA?.method ?? '',
        'right': result.requestB?.method ?? '',
        'changed': result.methodChanged,
      },
      'headers': result.headerDiffs.map((d) => {
        'key': d.fieldName,
        'left': d.oldValue ?? '',
        'right': d.newValue ?? '',
        'type': _compareTypeToString(d.type),
      }).toList(),
      'body': {
        'left': result.bodyDiff?.oldValue ?? '',
        'right': result.bodyDiff?.newValue ?? '',
        'changed': result.bodyDiff?.hasChanged ?? false,
      },
      'totalChanges': result.totalChanges,
      'summary': result.summary,
    };
  }

  String _compareTypeToString(CompareType type) {
    switch (type) {
      case CompareType.added: return 'added';
      case CompareType.removed: return 'removed';
      case CompareType.modified: return 'modified';
      case CompareType.unchanged: return 'unchanged';
    }
  }
}
