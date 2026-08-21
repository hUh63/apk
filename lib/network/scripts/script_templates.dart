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

/// 脚本模板库 - 提供常用的脚本模板
/// 支持 JavaScript、Dart、Shell 三种语言
class ScriptTemplates {
  ScriptTemplates._();

  /// JavaScript 脚本模板
  static const Map<String, JSScriptTemplate> jsTemplates = {
    'log_request': JSScriptTemplate(
      id: 'log_request',
      name: '记录请求日志',
      description: '在控制台打印请求的 URL 和方法',
      language: ScriptLanguage.javascript,
      category: ScriptCategory.logging,
      code: '''
// 记录请求日志
function onRequest(request) {
  console.log('[ProxyPin] Request:', request.method, request.url);
  return request;
}
''',
      tags: ['日志', '请求', '基础'],
    ),
    'modify_header': JSScriptTemplate(
      id: 'modify_header',
      name: '修改请求头',
      description: '添加或修改请求头信息',
      language: ScriptLanguage.javascript,
      category: ScriptCategory.modification,
      code: '''
// 修改请求头
function onRequest(request) {
  // 添加自定义请求头
  request.headers['X-Custom-Header'] = 'ProxyPin';
  request.headers['X-User-ID'] = '12345';
  
  // 修改 User-Agent
  request.headers['User-Agent'] = 'ProxyPin/1.0';
  
  return request;
}
''',
      tags: ['请求头', '修改', '常用'],
    ),
    'mock_response': JSScriptTemplate(
      id: 'mock_response',
      name: 'Mock 响应',
      description: '返回固定的 Mock 数据',
      language: ScriptLanguage.javascript,
      category: ScriptCategory.mock,
      code: '''
// Mock 响应
function onResponse(response) {
  // 返回固定的 JSON 数据
  response.statusCode = 200;
  response.headers['Content-Type'] = 'application/json';
  response.body = JSON.stringify({
    success: true,
    data: {
      id: 1,
      name: 'Mock Data',
      timestamp: Date.now()
    },
    message: 'This is a mocked response'
  });
  
  return response;
}
''',
      tags: ['Mock', '响应', '测试'],
    ),
    'delay_request': JSScriptTemplate(
      id: 'delay_request',
      name: '延迟请求',
      description: '模拟网络延迟',
      language: ScriptLanguage.javascript,
      category: ScriptCategory.testing,
      code: '''
// 延迟请求 (模拟慢速网络)
async function onRequest(request) {
  const delay = 2000; // 延迟 2 秒
  console.log(`[ProxyPin] Delaying request for ${delay}ms`);
  await new Promise(resolve => setTimeout(resolve, delay));
  return request;
}
''',
      tags: ['延迟', '测试', '性能'],
    ),
    'block_url': JSScriptTemplate(
      id: 'block_url',
      name: '拦截特定 URL',
      description: '阻止特定 URL 的请求',
      language: ScriptLanguage.javascript,
      category: ScriptCategory.blocking,
      code: '''
// 拦截特定 URL
function onRequest(request) {
  const blockedUrls = [
    'analytics.example.com',
    'tracking.example.com',
    'ads.example.com'
  ];
  
  for (const url of blockedUrls) {
    if (request.url.includes(url)) {
      console.log('[ProxyPin] Blocked request:', request.url);
      return null; // 返回 null 阻止请求
    }
  }
  
  return request;
}
''',
      tags: ['拦截', '屏蔽', '广告'],
    ),
    'inject_script': JSScriptTemplate(
      id: 'inject_script',
      name: '注入 JavaScript',
      description: '向 HTML 响应注入 JavaScript 代码',
      language: ScriptLanguage.javascript,
      category: ScriptCategory.injection,
      code: '''
// 向 HTML 注入 JavaScript
function onResponse(response) {
  const contentType = response.headers['Content-Type'] || '';
  
  if (contentType.includes('text/html')) {
    const script = `
      <script>
        console.log('[Injected Script] Page loaded');
        document.addEventListener('DOMContentLoaded', () => {
          console.log('[Injected Script] DOM ready');
        });
      </script>
    `;
    
    const body = new TextDecoder().decode(response.body);
    const modifiedBody = body.replace('</body>', script + '</body>');
    response.body = new TextEncoder().encode(modifiedBody);
  }
  
  return response;
}
''',
      tags: ['注入', 'HTML', 'JavaScript'],
    ),
  ];

  /// Dart 脚本模板
  static const Map<String, DartScriptTemplate> dartTemplates = {
    'log_request_dart': DartScriptTemplate(
      id: 'log_request_dart',
      name: '记录请求日志',
      description: '打印请求详情到控制台',
      language: ScriptLanguage.dart,
      category: ScriptCategory.logging,
      code: '''
// 记录请求日志
Future<HttpRequest?> onRequest(HttpRequest request) async {
  print('[ProxyPin] Request: \${request.method} \${request.requestUrl}');
  print('[ProxyPin] Headers: \${request.headers}');
  print('[ProxyPin] Body Length: \${request.contentLength}');
  return request;
}
''',
      tags: ['日志', '请求', 'Dart'],
    ),
    'modify_response_dart': DartScriptTemplate(
      id: 'modify_response_dart',
      name: '修改响应数据',
      description: '修改响应内容',
      language: ScriptLanguage.dart,
      category: ScriptCategory.modification,
      code: '''
// 修改响应数据
Future<HttpResponse?> onResponse(HttpRequest request, HttpResponse response) async {
  // 修改状态码
  response.statusCode = 200;
  
  // 修改响应头
  response.headers['X-Modified-By'] = 'ProxyPin';
  
  // 修改响应体
  final originalBody = response.bodyAsString;
  response.body = utf8.encode('Modified by ProxyPin: \$originalBody');
  
  return response;
}
''',
      tags: ['响应', '修改', 'Dart'],
    ),
    'cache_response_dart': DartScriptTemplate(
      id: 'cache_response_dart',
      name: '响应缓存',
      description: '缓存响应数据',
      language: ScriptLanguage.dart,
      category: ScriptCategory.caching,
      code: '''
// 简单的响应缓存
final Map<String, _CachedResponse> _cache = {};

class _CachedResponse {
  final HttpResponse response;
  final DateTime cachedAt;
  _CachedResponse(this.response, this.cachedAt);
}

Future<HttpResponse?> onResponse(HttpRequest request, HttpResponse response) async {
  // 缓存 GET 请求的响应
  if (request.method == 'GET') {
    _cache[request.requestId] = _CachedResponse(
      response,
      DateTime.now(),
    );
  }
  
  return response;
}
''',
      tags: ['缓存', '响应', 'Dart'],
    ),
  ];

  /// Shell 脚本模板
  static const Map<String, ShellScriptTemplate> shellTemplates = {
    'curl_request': ShellScriptTemplate(
      id: 'curl_request',
      name: 'cURL 请求',
      description: '使用 cURL 发送请求',
      language: ScriptLanguage.shell,
      category: ScriptCategory.testing,
      code: r'''
# 使用 cURL 发送请求
#!/bin/bash

URL="https://api.example.com/data"
METHOD="GET"
HEADERS=(
  "-H 'Content-Type: application/json'"
  "-H 'Authorization: Bearer YOUR_TOKEN'"
)

curl -X $METHOD "$URL" "${HEADERS[@]}" \
  -d '{"key": "value"}'
''',
      tags: ['cURL', '请求', '测试'],
    ),
    'parse_json': ShellScriptTemplate(
      id: 'parse_json',
      name: '解析 JSON',
      description: '使用 jq 解析 JSON 数据',
      language: ScriptLanguage.shell,
      category: ScriptCategory.processing,
      code: r'''
# 使用 jq 解析 JSON
#!/bin/bash

JSON_RESPONSE='{"success":true,"data":{"id":1,"name":"test"}}'

# 提取字段
echo "$JSON_RESPONSE" | jq '.success'
echo "$JSON_RESPONSE" | jq '.data.id'
echo "$JSON_RESPONSE" | jq '.data.name'

# 格式化输出
echo "$JSON_RESPONSE" | jq '.'
''',
      tags: ['JSON', '解析', 'jq'],
    ),
    'log_traffic': ShellScriptTemplate(
      id: 'log_traffic',
      name: '记录流量',
      description: '将流量记录到文件',
      language: ScriptLanguage.shell,
      category: ScriptCategory.logging,
      code: r'''
# 记录流量到文件
#!/bin/bash

LOG_FILE="/tmp/proxypin_traffic.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Request captured" >> "$LOG_FILE"
# 可以添加更多逻辑来处理请求数据
''',
      tags: ['日志', '流量', '文件'],
    ),
  };

  /// 获取所有 JavaScript 模板
  static List<JSScriptTemplate> getAllJSTemplates() {
    return jsTemplates.values.toList();
  }

  /// 获取所有 Dart 模板
  static List<DartScriptTemplate> getAllDartTemplates() {
    return dartTemplates.values.toList();
  }

  /// 获取所有 Shell 模板
  static List<ShellScriptTemplate> getAllShellTemplates() {
    return shellTemplates.values.toList();
  }

  /// 根据 ID 获取 JavaScript 模板
  static JSScriptTemplate? getJSTemplate(String id) {
    return jsTemplates[id];
  }

  /// 根据 ID 获取 Dart 模板
  static DartScriptTemplate? getDartTemplate(String id) {
    return dartTemplates[id];
  }

  /// 根据 ID 获取 Shell 模板
  static ShellScriptTemplate? getShellTemplate(String id) {
    return shellTemplates[id];
  }

  /// 根据类别获取 JavaScript 模板
  static List<JSScriptTemplate> getJSTemplatesByCategory(ScriptCategory category) {
    return jsTemplates.values.where((t) => t.category == category).toList();
  }

  /// 根据标签搜索 JavaScript 模板
  static List<JSScriptTemplate> searchJSTemplates(String query) {
    final lowerQuery = query.toLowerCase();
    return jsTemplates.values.where((t) {
      return t.name.toLowerCase().contains(lowerQuery) ||
          t.description.toLowerCase().contains(lowerQuery) ||
          t.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }
}

/// 脚本语言枚举
enum ScriptLanguage {
  javascript('JavaScript', 'js'),
  dart('Dart', 'dart'),
  shell('Shell', 'sh');

  final String displayName;
  final String extension;

  const ScriptLanguage(this.displayName, this.extension);
}

/// 脚本类别枚举
enum ScriptCategory {
  logging('日志记录'),
  modification('数据修改'),
  mock('Mock 数据'),
  testing('测试'),
  blocking('拦截屏蔽'),
  injection('代码注入'),
  caching('缓存'),
  processing('数据处理');

  final String displayName;

  const ScriptCategory(this.displayName);
}

/// JavaScript 脚本模板
class JSScriptTemplate {
  final String id;
  final String name;
  final String description;
  final ScriptLanguage language;
  final ScriptCategory category;
  final String code;
  final List<String> tags;

  const JSScriptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.language,
    required this.category,
    required this.code,
    required this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'language': language.name,
      'category': category.name,
      'code': code,
      'tags': tags,
    };
  }
}

/// Dart 脚本模板
class DartScriptTemplate {
  final String id;
  final String name;
  final String description;
  final ScriptLanguage language;
  final ScriptCategory category;
  final String code;
  final List<String> tags;

  const DartScriptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.language,
    required this.category,
    required this.code,
    required this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'language': language.name,
      'category': category.name,
      'code': code,
      'tags': tags,
    };
  }
}

/// Shell 脚本模板
class ShellScriptTemplate {
  final String id;
  final String name;
  final String description;
  final ScriptLanguage language;
  final ScriptCategory category;
  final String code;
  final List<String> tags;

  const ShellScriptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.language,
    required this.category,
    required this.code,
    required this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'language': language.name,
      'category': category.name,
      'code': code,
      'tags': tags,
    };
  }
}
