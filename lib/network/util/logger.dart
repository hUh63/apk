import 'package:logger/logger.dart';
export 'package:logger/logger.dart' show Logger, PrettyPrinter, Level;

/// 由 UI 层注册（LogManager），把每次运行日志同步进内存队列，
/// 供「日志管理」页实时查看（此前日志只输出到控制台，页面无数据）。
void Function(Level level, String message, Object? error, StackTrace? stackTrace)? logBridge;

/// 桥接打印机：格式化输出交给 PrettyPrinter（控制台），同时把原始日志转发到内存队列。
/// 选择在 Printer(log(LogEvent)) 层桥接，是因为 logger 2.x 的 OutputEvent 已不含
/// message/error 字段，而 LogEvent 各版本字段稳定（level/message/error/stackTrace）。
class _BridgingPrinter extends LogPrinter {
  final PrettyPrinter _inner;

  _BridgingPrinter()
      : _inner = PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 15,
          lineLength: 120,
          colors: true,
          printEmojis: false,
          excludeBox: {Level.info: true, Level.debug: true},
        );

  @override
  List<String> log(LogEvent event) {
    try {
      final msg = switch (event.message) {
        String s => s,
        null => '',
        dynamic other => other.toString(),
      };
      logBridge?.call(event.level, msg, event.error, event.stackTrace);
    } catch (_) {/* 桥接失败不影响控制台输出 */}
    return _inner.log(event);
  }
}

final logger = Logger(printer: _BridgingPrinter());
