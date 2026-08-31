/*
 * 搜索历史（上游 #217）：记录最近使用的关键词，快速重新搜索。
 * SharedPreferences 存储，去重置顶，最多 8 条。
 */
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistory {
  static const String _key = 'searchHistory';
  static const int _maxCount = 8;

  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      return list.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  /// 记录一条关键词（去重置顶）
  static Future<void> record(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty || k.length < 2) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(_key) ?? []).whereType<String>().toList();
      list.removeWhere((e) => e == k);
      list.insert(0, k);
      while (list.length > _maxCount) {
        list.removeLast();
      }
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  /// 序列化辅助（保留给导入导出扩展）
  static String encode(List<String> list) => jsonEncode(list);
}
