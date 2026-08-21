import 'package:logger/logger.dart';
export 'package:logger/logger.dart' show Logger, PrettyPrinter, Level;

final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 15,
      lineLength: 120,
      colors: true,
      printEmojis: false,
      excludeBox: {Level.info: true, Level.debug: true},
    ));
