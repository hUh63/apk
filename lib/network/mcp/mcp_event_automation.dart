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

import 'dart:async';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/util/logger.dart';

/// MCP 事件触发自动化框架
/// 支持监听网络请求事件、网络状态变化事件等
/// @author wanghongen
/// 2026-08-12
class McpEventAutomation {
  static final McpEventAutomation _instance = McpEventAutomation._internal();
  factory McpEventAutomation() => _instance;
  McpEventAutomation._internal();

  // 事件监听器
  final Map<String, List<EventCallback>> _listeners = {};
  
  // 事件历史记录（用于调试）
  final List<EventRecord> _eventHistory = [];
  static const int _maxHistorySize = 100;

  /// 事件回调类型
  typedef EventCallback = void Function(dynamic data);

  /// 事件记录
  class EventRecord {
    final String eventName;
    final DateTime timestamp;
    final dynamic data;
    
    EventRecord(this.eventName, this.data) : timestamp = DateTime.now();
    
    @override
    String toString() => '[$timestamp] $eventName: $data';
  }

  /// 添加事件监听器
  void addListener(String eventName, EventCallback callback) {
    _listeners.putIfAbsent(eventName, () => []);
    _listeners[eventName]!.add(callback);
    logger.d('添加事件监听器：$eventName');
  }

  /// 移除事件监听器
  void removeListener(String eventName, EventCallback callback) {
    _listeners[eventName]?.remove(callback);
    if (_listeners[eventName]?.isEmpty == true) {
      _listeners.remove(eventName);
    }
  }

  /// 移除所有监听器
  void removeAllListeners(String eventName) {
    _listeners.remove(eventName);
  }

  /// 清除所有监听器
  void clearAllListeners() {
    _listeners.clear();
  }

  /// 触发事件
  void _triggerEvent(String eventName, dynamic data) {
    final callbacks = _listeners[eventName] ?? [];
    if (callbacks.isEmpty) return;
    
    // 记录事件历史
    _eventHistory.add(EventRecord(eventName, data));
    if (_eventHistory.length > _maxHistorySize) {
      _eventHistory.removeAt(0);
    }
    
    // 触发所有监听器
    for (final callback in callbacks) {
      try {
        callback(data);
      } catch (e, stackTrace) {
        logger.e('事件回调执行失败：$eventName', error: e, stackTrace: stackTrace);
      }
    }
  }

  /// 获取事件历史
  List<EventRecord> getEventHistory({int? limit}) {
    if (limit == null) return List.unmodifiable(_eventHistory);
    final start = _eventHistory.length - limit.clamp(0, _eventHistory.length);
    return _eventHistory.sublist(start);
  }

  // ==================== HTTP 请求事件 ====================

  /// 监听 HTTP 请求事件
  /// [urlPattern] URL 正则表达式模式，匹配则触发
  void onHttpRequest(Pattern urlPattern, EventCallback callback) {
    final eventName = 'http_request:$urlPattern';
    addListener(eventName, callback);
  }

  /// 触发 HTTP 请求事件
  void triggerHttpRequest(HttpRequest request) {
    // 触发所有 HTTP 请求监听器
    _listeners.forEach((eventName, callbacks) {
      if (eventName.startsWith('http_request:')) {
        final patternStr = eventName.substring('http_request:'.length);
        try {
          final pattern = RegExp(patternStr);
          if (pattern.hasMatch(request.url)) {
            for (final callback in callbacks) {
              callback(request);
            }
          }
        } catch (e) {
          logger.w('无效的正则表达式：$patternStr', error: e);
        }
      }
    });
  }

  /// 监听特定 API 路径的请求
  void onApiRequest(String apiPath, EventCallback callback) {
    onHttpRequest(RegExp(r'.*' + RegExp.escape(apiPath) + r'.*'), callback);
  }

  /// 监听特定域名的请求
  void onDomainRequest(String domain, EventCallback callback) {
    onHttpRequest(RegExp(r'https?://' + RegExp.escape(domain)), callback);
  }

  // ==================== 网络状态事件 ====================

  /// 网络状态枚举
  enum NetworkStatus { connected, disconnected, wifi, mobile, weak }

  /// 监听网络状态变化
  void onNetworkStatusChange(NetworkStatus status, EventCallback callback) {
    addListener('network_status:$status', callback);
  }

  /// 触发网络状态变化事件
  void triggerNetworkStatusChange(NetworkStatus status) {
    _triggerEvent('network_status:$status', {'status': status, 'timestamp': DateTime.now()});
  }

  // ==================== 代理状态事件 ====================

  /// 代理状态枚举
  enum ProxyStatus { started, stopped, paused, resumed }

  /// 监听代理状态变化
  void onProxyStatusChange(ProxyStatus status, EventCallback callback) {
    addListener('proxy_status:$status', callback);
  }

  /// 触发代理状态变化事件
  void triggerProxyStatusChange(ProxyStatus status) {
    _triggerEvent('proxy_status:$status', {'status': status, 'timestamp': DateTime.now()});
  }

  // ==================== 脚本事件 ====================

  /// 监听脚本执行事件
  void onScriptEvent(String scriptId, String eventType, EventCallback callback) {
    addListener('script:$scriptId:$eventType', callback);
  }

  /// 触发脚本执行事件
  void triggerScriptEvent(String scriptId, String eventType, dynamic data) {
    _triggerEvent('script:$scriptId:$eventType', {
      'scriptId': scriptId,
      'eventType': eventType,
      'data': data,
      'timestamp': DateTime.now()
    });
  }

  // ==================== 抓包事件 ====================

  /// 监听抓包开始事件
  void onCaptureStart(EventCallback callback) {
    addListener('capture_start', callback);
  }

  /// 触发抓包开始事件
  void triggerCaptureStart() {
    _triggerEvent('capture_start', {'timestamp': DateTime.now()});
  }

  /// 监听抓包停止事件
  void onCaptureStop(EventCallback callback) {
    addListener('capture_stop', callback);
  }

  /// 触发抓包停止事件
  void triggerCaptureStop() {
    _triggerEvent('capture_stop', {'timestamp': DateTime.now()});
  }

  /// 监听抓包数量达到阈值事件
  void onCaptureCountThreshold(int threshold, EventCallback callback) {
    addListener('capture_threshold:$threshold', callback);
  }

  /// 触发抓包数量阈值事件
  void triggerCaptureCountThreshold(int count, int threshold) {
    _triggerEvent('capture_threshold:$threshold', {
      'count': count,
      'threshold': threshold,
      'timestamp': DateTime.now()
    });
  }
}

/// 使用示例
class McpEventAutomationExample {
  /// 示例：监听 API 请求并自动记录
  static void setupApiMonitoring() {
    final automation = McpEventAutomation();
    
    // 监听所有 /api/ 开头的请求
    automation.onApiRequest('/api/', (request) {
      logger.i('检测到 API 请求：${request.url}');
      // 这里可以添加自动保存、转发等逻辑
    });
    
    // 监听特定域名的请求
    automation.onDomainRequest('api.example.com', (request) {
      logger.i('检测到 example.com API 请求');
    });
  }

  /// 示例：监听网络状态变化
  static void setupNetworkMonitor() {
    final automation = McpEventAutomation();
    
    automation.onNetworkStatusChange(McpEventAutomation.NetworkStatus.disconnected, (_) {
      logger.w('网络断开，暂停抓包');
      // 自动暂停抓包
    });
    
    automation.onNetworkStatusChange(McpEventAutomation.NetworkStatus.connected, (_) {
      logger.i('网络已连接，恢复抓包');
      // 自动恢复抓包
    });
  }

  /// 示例：监听抓包数量
  static void setupCaptureThreshold(int threshold) {
    final automation = McpEventAutomation();
    
    automation.onCaptureCountThreshold(threshold, (data) {
      logger.w('抓包数量达到阈值：${data['count']}');
      // 可以自动清理旧数据或停止抓包
    });
  }

  /// 示例：监听代理状态
  static void setupProxyMonitor() {
    final automation = McpEventAutomation();
    
    automation.onProxyStatusChange(McpEventAutomation.ProxyStatus.started, (_) {
      logger.i('代理已启动');
    });
    
    automation.onProxyStatusChange(McpEventAutomation.ProxyStatus.stopped, (_) {
      logger.i('代理已停止');
    });
  }
}
