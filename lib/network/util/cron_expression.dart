/*
 * Cron 表达式解析（5 字段：分 时 日 月 星期）
 * 支持 * ? , - / ；星期字段 0-6（0=周日，亦兼容 7）
 * 供 MCP 定时任务调度与工具箱 Cron 预览共用。
 */

/// 单条 Cron 表达式
class CronExpression {
  /// 分 时 日 月 星期
  final String expression;

  const CronExpression(this.expression);

  bool get isValid => next(DateTime.now()) != null;

  /// 计算 [after] 之后的下一个匹配时间（逐分钟扫描，最多 366 天）
  DateTime? next(DateTime after) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) return null;
    var t = DateTime(after.year, after.month, after.day, after.hour, after.minute)
        .add(const Duration(minutes: 1));
    final limit = t.add(const Duration(days: 366));
    while (t.isBefore(limit)) {
      if (matches(t)) return t;
      t = t.add(const Duration(minutes: 1));
    }
    return null;
  }

  bool matches(DateTime t) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) return false;
    return _field(parts[0], t.minute) &&
        _field(parts[1], t.hour) &&
        _field(parts[2], t.day) &&
        _field(parts[3], t.month) &&
        _field(parts[4], t.weekday == 7 ? 0 : t.weekday);
  }

  bool _field(String expr, int value) {
    for (final seg in expr.split(',')) {
      var step = 1;
      var body = seg;
      if (seg.contains('/')) {
        final idx = seg.indexOf('/');
        body = seg.substring(0, idx);
        step = int.tryParse(seg.substring(idx + 1)) ?? 1;
        if (step <= 0) return false;
      }
      int? lo;
      int? hi;
      if (body == '*' || body == '?') {
        lo = 0;
        hi = 59;
      } else if (body.contains('-')) {
        final p = body.split('-');
        lo = int.tryParse(p[0]);
        hi = int.tryParse(p[1]);
      } else {
        final v = int.tryParse(body);
        if (v == null) return false;
        if (step == 1) {
          if (value == v) return true;
          continue;
        }
        lo = v;
        hi = 59;
      }
      if (lo == null || hi == null) return false;
      if (value >= lo && value <= hi && (value - lo) % step == 0) return true;
    }
    return false;
  }
}
