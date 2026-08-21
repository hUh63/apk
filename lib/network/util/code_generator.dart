/*
 * 代码生成器 - 支持多种语言 HTTP 请求代码生成
 * 支持：cURL、Python、JavaScript、Dart、Java、Go、PHP、Ruby
 */

import 'dart:convert';
import 'package:proxypin/network/http/http.dart';

/// 编程语言枚举
enum CodeLanguage {
  curl('cURL', 'curl'),
  python('Python', 'python'),
  javascript('JavaScript', 'javascript'),
  dart('Dart', 'dart'),
  java('Java', 'java'),
  go('Go', 'go'),
  php('PHP', 'php'),
  ruby('Ruby', 'ruby'),
  http('HTTP', 'http');

  final String displayName;
  final String fileExtension;

  const CodeLanguage(this.displayName, this.fileExtension);
}

/// 代码生成器
class CodeGenerator {
  /// 生成指定语言的代码
  String generate(Request request, CodeLanguage language) {
    switch (language) {
      case CodeLanguage.curl:
        return _generateCurl(request);
      case CodeLanguage.python:
        return _generatePython(request);
      case CodeLanguage.javascript:
        return _generateJavaScript(request);
      case CodeLanguage.dart:
        return _generateDart(request);
      case CodeLanguage.java:
        return _generateJava(request);
      case CodeLanguage.go:
        return _generateGo(request);
      case CodeLanguage.php:
        return _generatePhp(request);
      case CodeLanguage.ruby:
        return _generateRuby(request);
      case CodeLanguage.http:
        return _generateHttpRaw(request);
    }
  }

  /// 生成 cURL 命令
  String _generateCurl(Request request) {
    final buffer = StringBuffer();
    buffer.write('curl -X ${request.method}');
    buffer.write(' \'${request.url}\'');

    // 添加请求头
    request.headers.forEach((key, value) {
      final escapedValue = value.replaceAll('\'', '\'\\\'\'');
      buffer.write(' \\\n  -H \'$key: $escapedValue\'');
    });

    // 添加请求体
    if (request.body.isNotEmpty) {
      final escapedBody = request.body.replaceAll('\'', '\'\\\'\'');
      buffer.write(' \\\n  --data-raw \'$escapedBody\'');
    }

    // 添加 Cookie
    if (request.cookies.isNotEmpty) {
      final cookieString = request.cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      buffer.write(' \\\n  -H \'Cookie: $cookieString\'');
    }

    // 忽略证书验证（如果是 HTTPS）
    if (request.url.startsWith('https://')) {
      buffer.write(' \\\n  --insecure');
    }

    return buffer.toString();
  }

  /// 生成 Python 代码 (requests 库)
  String _generatePython(Request request) {
    final buffer = StringBuffer();
    buffer.writeln('import requests');
    buffer.writeln();

    buffer.writeln('url = "${request.url}"');
    buffer.writeln();

    // 请求头
    if (request.headers.isNotEmpty) {
      buffer.writeln('headers = {');
      request.headers.forEach((key, value) {
        buffer.writeln('    \'$key\': \'$value\',');
      });
      buffer.writeln('}');
      buffer.writeln();
    }

    // 请求体
    if (request.body.isNotEmpty) {
      final isJson = request.headers['content-type']?.contains('application/json') ?? false;
      if (isJson) {
        buffer.writeln('import json');
        buffer.writeln('data = json.loads(\'${request.body.replaceAll('\'', '\\\'')}\')');
      } else {
        buffer.writeln('data = \'${request.body.replaceAll('\'', '\\\'')}\'');
      }
      buffer.writeln();
    }

    // 查询参数
    final uri = Uri.parse(request.url);
    if (uri.queryParameters.isNotEmpty) {
      buffer.writeln('params = {');
      uri.queryParameters.forEach((key, value) {
        buffer.writeln('    \'$key\': \'$value\',');
      });
      buffer.writeln('}');
      buffer.writeln();
    }

    // 生成请求代码
    final method = request.method.toLowerCase();
    buffer.write('response = requests.$method(');
    buffer.write('url');
    if (request.headers.isNotEmpty) buffer.write(', headers=headers');
    if (request.body.isNotEmpty) buffer.write(', data=data');
    if (uri.queryParameters.isNotEmpty) buffer.write(', params=params');
    buffer.writeln(')');
    buffer.writeln();
    buffer.writeln('print(response.status_code)');
    buffer.writeln('print(response.text)');

    return buffer.toString();
  }

  /// 生成 JavaScript 代码 (fetch API)
  String _generateJavaScript(Request request) {
    final buffer = StringBuffer();
    buffer.writeln('const url = "${request.url}";');
    buffer.writeln();

    buffer.writeln('const options = {');
    buffer.writeln('  method: \'${request.method}\',');

    // 请求头
    if (request.headers.isNotEmpty) {
      buffer.writeln('  headers: {');
      request.headers.forEach((key, value) {
        buffer.writeln('    \'$key\': \'$value\',');
      });
      buffer.writeln('  },');
    }

    // 请求体
    if (request.body.isNotEmpty) {
      buffer.writeln('  body: ${_jsBody(request.body, request.headers['content-type'])},');
    }

    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('fetch(url, options)');
    buffer.writeln('  .then(response => response.text())');
    buffer.writeln('  .then(data => console.log(data))');
    buffer.writeln('  .catch(error => console.error(error));');

    return buffer.toString();
  }

  String _jsBody(String body, String? contentType) {
    if (contentType?.contains('application/json') ?? false) {
      return 'JSON.stringify($body)';
    }
    return '`$body`';
  }

  /// 生成 Dart 代码 (http 包)
  String _generateDart(Request request) {
    final buffer = StringBuffer();
    buffer.writeln('import \'package:http/http.dart\' as http;');
    buffer.writeln();

    buffer.writeln('void main() async {');
    buffer.writeln('  final url = Uri.parse("${request.url}");');
    buffer.writeln();

    // 请求头
    if (request.headers.isNotEmpty) {
      buffer.writeln('  final headers = {');
      request.headers.forEach((key, value) {
        buffer.writeln('    \'$key\': \'$value\',');
      });
      buffer.writeln('  };');
      buffer.writeln();
    }

    // 生成请求代码
    final method = request.method.toLowerCase();
    buffer.write('  final response = await http.$method(');
    buffer.write('url');
    if (request.headers.isNotEmpty) buffer.write(', headers: headers');
    if (request.body.isNotEmpty) buffer.write(', body: \'${request.body.replaceAll('\'', '\\\'')}\'');
    buffer.writeln(');');
    buffer.writeln();
    buffer.writeln('  print(\'Status: \${response.statusCode}\');');
    buffer.writeln('  print(\'Body: \${response.body}\');');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// 生成 Java 代码 (OkHttp)
  String _generateJava(Request request) {
    final buffer = StringBuffer();
    buffer.writeln('import okhttp3.*;');
    buffer.writeln('import java.io.IOException;');
    buffer.writeln();
    buffer.writeln('public class RequestExample {');
    buffer.writeln('  public static void main(String[] args) throws IOException {');
    buffer.writeln('    OkHttpClient client = new OkHttpClient();');
    buffer.writeln();
    buffer.writeln('    Request request = new Request.Builder()');
    buffer.writeln('      .url("${request.url}")');

    // 请求头
    request.headers.forEach((key, value) {
      buffer.writeln('      .addHeader("$key", "$value")');
    });

    // 请求体
    if (request.body.isNotEmpty) {
      final mediaType = request.headers['content-type'] ?? 'application/json';
      buffer.writeln('      .${_javaMethod(request.method)}(RequestBody.create(MediaType.parse("$mediaType"), "${request.body.replaceAll('\'', '\\\'')}"))');
    } else if (request.method != 'GET') {
      buffer.writeln('      .${_javaMethod(request.method)}(null)');
    }

    buffer.writeln('      .build();');
    buffer.writeln();
    buffer.writeln('    Response response = client.newCall(request).execute();');
    buffer.writeln('    System.out.println(response.code());');
    buffer.writeln('    System.out.println(response.body().string());');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  private static String ${_javaMethod(request.method)}(RequestBody body) {');
    buffer.writeln('    return "${request.method.toLowerCase()}";');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  String _javaMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return 'get';
      case 'POST': return 'post';
      case 'PUT': return 'put';
      case 'DELETE': return 'delete';
      case 'PATCH': return 'patch';
      default: return 'method';
    }
  }

  /// 生成 Go 代码
  String _generateGo(Request request) {
    final buffer = StringBuffer();
    buffer.writeln('package main');
    buffer.writeln();
    buffer.writeln('import (');
    buffer.writeln('  "fmt"');
    buffer.writeln('  "net/http"');
    buffer.writeln('  "io/ioutil"');
    buffer.writeln('  "strings"');
    buffer.writeln(')');
    buffer.writeln();
    buffer.writeln('func main() {');
    buffer.writeln('  client := &http.Client{}');
    buffer.writeln();

    // 请求体
    if (request.body.isNotEmpty) {
      buffer.writeln('  var data = strings.NewReader(`${request.body.replaceAll('`', '\\`')}`)');
      buffer.writeln();
    }

    buffer.writeln('  req, err := http.NewRequest("${request.method}", "${request.url}", ${request.body.isNotEmpty ? 'data' : 'nil'})');
    buffer.writeln('  if err != nil {');
    buffer.writeln('    panic(err)');
    buffer.writeln('  }');

    // 请求头
    request.headers.forEach((key, value) {
      buffer.writeln('  req.Header.Set("$key", "$value")');
    });

    buffer.writeln();
    buffer.writeln('  resp, err := client.Do(req)');
    buffer.writeln('  if err != nil {');
    buffer.writeln('    panic(err)');
    buffer.writeln('  }');
    buffer.writeln('  defer resp.Body.Close()');
    buffer.writeln();
    buffer.writeln('  body, _ := ioutil.ReadAll(resp.Body)');
    buffer.writeln('  fmt.Println(string(body))');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// 生成 PHP 代码
  String _generatePhp(Request request) {
    final buffer = StringBuffer();
    buffer.writeln('<?php');
    buffer.writeln();
    buffer.writeln('\$curl = curl_init();');
    buffer.writeln();
    buffer.writeln('curl_setopt_array(\$curl, [');
    buffer.writeln('  CURLOPT_URL => "${request.url}",');
    buffer.writeln('  CURLOPT_RETURNTRANSFER => true,');
    buffer.writeln('  CURLOPT_ENCODING => "",');
    buffer.writeln('  CURLOPT_MAXREDIRS => 10,');
    buffer.writeln('  CURLOPT_TIMEOUT => 30,');
    buffer.writeln('  CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,');
    buffer.writeln('  CURLOPT_CUSTOMREQUEST => "${request.method}",');

    // 请求体
    if (request.body.isNotEmpty) {
      buffer.writeln('  CURLOPT_POSTFIELDS => "${request.body.replaceAll('\'', '\\\'')}",');
    }

    // 请求头
    if (request.headers.isNotEmpty) {
      buffer.writeln('  CURLOPT_HTTPHEADER => [');
      request.headers.forEach((key, value) {
        buffer.writeln('    "$key: $value",');
      });
      buffer.writeln('  ],');
    }

    buffer.writeln(']);');
    buffer.writeln();
    buffer.writeln('\$response = curl_exec(\$curl);');
    buffer.writeln('\$err = curl_error(\$curl);');
    buffer.writeln();
    buffer.writeln('curl_close(\$curl);');
    buffer.writeln();
    buffer.writeln('if (\$err) {');
    buffer.writeln('  echo "cURL Error #:" . \$err;');
    buffer.writeln('} else {');
    buffer.writeln('  echo \$response;');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// 生成 Ruby 代码
  String _generateRuby(Request request) {
    final buffer = StringBuffer();
    buffer.writeln('require \'uri\'');
    buffer.writeln('require \'net/http\'');
    buffer.writeln();
    buffer.writeln('url = URI("${request.url}")');
    buffer.writeln();
    buffer.writeln('https = Net::HTTP.new(url.host, url.port)');
    buffer.writeln('https.use_ssl = true if url.scheme == "https"');
    buffer.writeln();
    buffer.writeln('request = Net::HTTP::${_rubyMethod(request.method)}.new(url)');

    // 请求头
    request.headers.forEach((key, value) {
      buffer.writeln('request["$key"] = "$value"');
    });

    // 请求体
    if (request.body.isNotEmpty) {
      buffer.writeln('request.body = "${request.body.replaceAll('\'', '\\\'')}"');
    }

    buffer.writeln();
    buffer.writeln('response = https.request(request)');
    buffer.writeln('puts response.read_body');

    return buffer.toString();
  }

  String _rubyMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return 'Get';
      case 'POST': return 'Post';
      case 'PUT': return 'Put';
      case 'DELETE': return 'Delete';
      case 'PATCH': return 'Patch';
      default: return 'Generic';
    }
  }

  /// 生成原始 HTTP 请求
  String _generateHttpRaw(Request request) {
    final buffer = StringBuffer();
    buffer.writeln('${request.method} ${Uri.parse(request.url).path} HTTP/1.1');
    buffer.writeln('Host: ${Uri.parse(request.url).host}');

    request.headers.forEach((key, value) {
      buffer.writeln('$key: $value');
    });

    buffer.writeln();
    if (request.body.isNotEmpty) {
      buffer.writeln(request.body);
    }

    return buffer.toString();
  }

  /// 生成多种语言代码
  Map<String, String> generateAll(Request request) {
    return {
      for (var lang in CodeLanguage.values)
        lang.displayName: generate(request, lang),
    };
  }
}
