/*
 * AI 请求分析（上游 #582）：把抓包的请求/响应摘要发给 OpenAI 兼容接口，
 * 返回接口功能解读、字段说明与风险提示。
 */

import 'dart:convert';
import 'dart:io' show HttpClient, HttpHeaders;

import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/http/http.dart';

class AiAnalyzer {
  AiAnalyzer._();

  static const String systemPrompt =
      '你是资深 Web/接口安全分析师。分析抓包数据时用简体中文，'
      '输出结构清晰：先一句话概括接口用途，再分「请求要点」「响应要点」「值得注意的风险或异常」三部分，'
      '敏感信息（密钥、token、手机号等）只提示存在并脱敏，不要原文复述。'
      '回答保持简洁专业，支持基于上下文继续追问。';

  static bool get isConfigured {
    final config = Configuration.loaded;
    return config != null && config.aiEnabled && config.aiApiKey.isNotEmpty;
  }

  /// 多轮对话：messages 为 [{role, content}]
  static Future<String> chat(List<Map<String, String>> messages) async {
    final config = Configuration.loaded;
    if (config == null || !config.aiEnabled || config.aiApiKey.isEmpty) {
      throw Exception('尚未配置 AI 服务：请到「设置 → MCP Connection → AI 分析」填写接口地址与 API Key');
    }

    final baseUrl = config.aiBaseUrl.endsWith('/')
        ? config.aiBaseUrl.substring(0, config.aiBaseUrl.length - 1)
        : config.aiBaseUrl;

    final client = HttpClient();
    try {
      final request2 = await client.postUrl(Uri.parse('$baseUrl/chat/completions'));
      request2.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request2.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${config.aiApiKey}');
      request2.add(utf8.encode(jsonEncode({
        'model': config.aiModel,
        'temperature': 0.3,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          ...messages,
        ],
      })));

      final response = await request2.close().timeout(const Duration(seconds: 90));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) {
        throw Exception('AI 接口返回 ${response.statusCode}：${_truncate(body, 300)}');
      }
      final data = jsonDecode(body);
      final content = data['choices']?[0]?['message']?['content'];
      if (content is! String || content.isEmpty) {
        throw Exception('AI 未返回内容：${_truncate(body, 300)}');
      }
      return content;
    } finally {
      client.close();
    }
  }

  /// 单请求分析（封装为一次 chat 调用）
  static Future<String> analyze(HttpRequest request) {
    return chat([
      {'role': 'user', 'content': '请分析这条抓包请求：\n\n${requestSummary(request)}'},
    ]);
  }

  /// 生成请求+响应的分析摘要（供 AI 输入与对话页附加展示）
  static String requestSummary(HttpRequest request) {
    final buf = StringBuffer();
    buf.writeln('${request.method} ${request.requestUrl}');
    try {
      buf.writeln('请求头:');
      request.headers.forEach((k, v) => buf.writeln('  $k: ${_truncate(v.toString(), 200)}'));
    } catch (_) {}
    try {
      final body = request.bodyAsString;
      if (body.isNotEmpty) {
        buf.writeln('请求体(${request.headers.contentType}):');
        buf.writeln(_truncate(body, 3500));
      }
    } catch (_) {}

    final response = request.response;
    if (response != null) {
      buf.writeln();
      buf.writeln('## 响应');
      buf.writeln('状态码: ${response.status.code} ${response.status.reasonPhrase}');
      try {
        response.headers.forEach((k, v) => buf.writeln('  $k: ${_truncate(v.toString(), 200)}'));
      } catch (_) {}
      try {
        final body = response.bodyAsString;
        if (body.isNotEmpty) {
          buf.writeln('响应体:');
          buf.writeln(_truncate(body, 3500));
        }
      } catch (_) {}
    } else {
      buf.writeln();
      buf.writeln('## 响应');
      buf.writeln('（响应尚未返回或未选中）');
    }
    return buf.toString();
  }

  static String _truncate(String s, int max) {
    s = s.trim();
    return s.length <= max ? s : '${s.substring(0, max)}…(已截断)';
  }
}
