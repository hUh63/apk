import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// MCP Screen Control - Dart 端桥接
///
/// 封装 Android 原生 MethodChannel "com.proxy/mcpScreen"，
/// 提供 UI 自动化和设备控制能力。
///
/// 仅 Android 平台可用，桌面端调用会抛出 UnsupportedError。
class McpScreen {
  static const _channel = MethodChannel('com.proxy/mcpScreen');

  static bool get isSupported => Platform.isAndroid;

  /// 获取设备信息（型号、品牌、Android 版本、IP、Root/无障碍状态）
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final result = await _channel.invokeMethod('getDeviceInfo');
    return Map<String, dynamic>.from(result);
  }

  /// 获取当前前台 Activity
  static Future<String> getCurrentActivity() async {
    return await _channel.invokeMethod('getCurrentActivity');
  }

  /// 导出当前 UI 层级
  /// [clickableOnly] 仅返回可点击元素
  /// [packageFilter] 按包名过滤
  static Future<String> dumpUi({bool clickableOnly = false, String? packageFilter}) async {
    return await _channel.invokeMethod('dumpUi', {
      'clickableOnly': clickableOnly,
      if (packageFilter != null) 'packageFilter': packageFilter,
    });
  }

  /// 点击坐标
  static Future<bool> tap(int x, int y) async {
    return await _channel.invokeMethod('tap', {'x': x, 'y': y});
  }

  /// 长按坐标（指定持续时长）
  static Future<bool> click(int x, int y, {int duration = 50}) async {
    return await _channel.invokeMethod('click', {'x': x, 'y': y, 'duration': duration});
  }

  /// 滑动手势
  static Future<bool> swipe(int x1, int y1, int x2, int y2, {int duration = 300}) async {
    return await _channel.invokeMethod('swipe', {
      'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'duration': duration,
    });
  }

  /// 按键事件
  /// keycode: 3=HOME, 4=BACK, 26=POWER, 82=MENU, 187=RECENTS
  static Future<bool> keyEvent(int keycode) async {
    return await _channel.invokeMethod('keyEvent', {'keycode': keycode});
  }

  /// 在当前焦点元素上输入文本
  static Future<bool> inputText(String text) async {
    return await _channel.invokeMethod('inputText', {'text': text});
  }

  /// 截屏（需 Root），返回 Base64 编码的 PNG
  static Future<String> screenshot() async {
    return await _channel.invokeMethod('screenshot');
  }

  /// 打开无障碍设置页面
  static Future<bool> openAccessibilitySettings() async {
    return await _channel.invokeMethod('openAccessibilitySettings');
  }

  /// 执行 Shell 命令
  /// [useSu] 是否使用 root 权限
  /// [timeoutMs] 超时时间（毫秒）
  static Future<Map<String, dynamic>> shell(String command, {bool useSu = false, int timeoutMs = 10000}) async {
    final result = await _channel.invokeMethod('shell', {
      'command': command,
      'useSu': useSu,
      'timeoutMs': timeoutMs,
    });
    return Map<String, dynamic>.from(result);
  }
}
