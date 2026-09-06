import 'package:logger/logger.dart';
export 'package:logger/logger.dart' show Logger, PrettyPrinter, Level;

/// 由 UI 层注册（LogManager），把每次运行日志同步进内存队列，
/// 供「日志管理」页实时查看（此前日志只输出到控制台，页面无数据）。
void Function(Level level, String message, Object? error, StackTrace? stackTrace)? logBridge;

final RegExp _ansiPattern = RegExp(r'\x1B\[[0-9;]*m');

/// 控制台输出 + 同步到内存日志的双通道输出
class _BridgedConsoleOutput extends ConsoleOutput {
  @override
  void output(OutputEvent event) {
    try {
      // PrettyPrinter 带 ANSI 色码，写入内存前剥离
      final clean = event.message.replaceAll(_ansiPattern, '');
      logBridge?.call(event.level, clean, event.error, event.stackTrace);
    } catch (_) {/* 桥接失败不影响控制台 */}
    super.output(event);
  }
}

final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 15,
      lineLength: 120,
      colors: true,
      printEmojis: false,
      excludeBox: {Level.info: true, Level.debug: true},
    ),
    output: _BridgedConsoleOutput());
