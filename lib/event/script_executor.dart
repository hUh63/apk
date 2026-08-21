/*
 * 脚本执行器 - 支持 Python/Shell/JavaScript 脚本执行
 * 通过 Process 运行外部解释器
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 脚本执行结果
class ScriptExecutionResult {
  final String scriptName;
  final String scriptType;
  final bool success;
  final String output;
  final String error;
  final int exitCode;
  final Duration duration;

  ScriptExecutionResult({
    required this.scriptName,
    required this.scriptType,
    required this.success,
    required this.output,
    required this.error,
    required this.exitCode,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'scriptName': scriptName,
        'scriptType': scriptType,
        'success': success,
        'output': output,
        'error': error,
        'exitCode': exitCode,
        'durationMs': duration.inMilliseconds,
      };
}

/// 脚本执行器
class ScriptExecutor {
  static final ScriptExecutor _instance = ScriptExecutor._internal();
  factory ScriptExecutor() => _instance;
  ScriptExecutor._internal();

  /// Python 解释器路径
  String pythonInterpreter = 'python3';

  /// Node.js 解释器路径
  String nodeInterpreter = 'node';

  /// Shell 解释器
  String shellInterpreter = '/bin/sh';

  /// 执行超时时间 (秒)
  int defaultTimeout = 30;

  /// 执行 Python 脚本
  Future<ScriptExecutionResult> executePython(
    String scriptPath, {
    List<String> args = const [],
    Map<String, String>? environment,
    String? workingDirectory,
    int? timeoutSeconds,
  }) async {
    return _executeScript(
      interpreter: pythonInterpreter,
      scriptPath: scriptPath,
      args: args,
      environment: environment,
      workingDirectory: workingDirectory,
      timeoutSeconds: timeoutSeconds ?? defaultTimeout,
      scriptType: 'python',
    );
  }

  /// 执行 Shell 脚本
  Future<ScriptExecutionResult> executeShell(
    String scriptPath, {
    List<String> args = const [],
    Map<String, String>? environment,
    String? workingDirectory,
    int? timeoutSeconds,
  }) async {
    return _executeScript(
      interpreter: shellInterpreter,
      scriptPath: scriptPath,
      args: args,
      environment: environment,
      workingDirectory: workingDirectory,
      timeoutSeconds: timeoutSeconds ?? defaultTimeout,
      scriptType: 'shell',
    );
  }

  /// 执行 JavaScript 脚本
  Future<ScriptExecutionResult> executeJavaScript(
    String scriptPath, {
    List<String> args = const [],
    Map<String, String>? environment,
    String? workingDirectory,
    int? timeoutSeconds,
  }) async {
    return _executeScript(
      interpreter: nodeInterpreter,
      scriptPath: scriptPath,
      args: args,
      environment: environment,
      workingDirectory: workingDirectory,
      timeoutSeconds: timeoutSeconds ?? defaultTimeout,
      scriptType: 'javascript',
    );
  }

  /// 执行内联 Python 代码
  Future<ScriptExecutionResult> executePythonCode(
    String code, {
    Map<String, String>? environment,
    String? workingDirectory,
    int? timeoutSeconds,
  }) async {
    return _executeCode(
      interpreter: pythonInterpreter,
      code: code,
      environment: environment,
      workingDirectory: workingDirectory,
      timeoutSeconds: timeoutSeconds ?? defaultTimeout,
      scriptType: 'python',
    );
  }

  /// 执行内联 Shell 命令
  Future<ScriptExecutionResult> executeShellCommand(
    String command, {
    Map<String, String>? environment,
    String? workingDirectory,
    int? timeoutSeconds,
  }) async {
    return _executeCode(
      interpreter: shellInterpreter,
      code: command,
      environment: environment,
      workingDirectory: workingDirectory,
      timeoutSeconds: timeoutSeconds ?? defaultTimeout,
      scriptType: 'shell',
    );
  }

  /// 执行内联 JavaScript 代码
  Future<ScriptExecutionResult> executeJavaScriptCode(
    String code, {
    Map<String, String>? environment,
    String? workingDirectory,
    int? timeoutSeconds,
  }) async {
    return _executeCode(
      interpreter: nodeInterpreter,
      code: code,
      environment: environment,
      workingDirectory: workingDirectory,
      timeoutSeconds: timeoutSeconds ?? defaultTimeout,
      scriptType: 'javascript',
    );
  }

  /// 通用脚本执行
  Future<ScriptExecutionResult> _executeScript({
    required String interpreter,
    required String scriptPath,
    required List<String> args,
    Map<String, String>? environment,
    String? workingDirectory,
    required int timeoutSeconds,
    required String scriptType,
  }) async {
    final stopwatch = Stopwatch()..start();
    final scriptName = File(scriptPath).uri.pathSegments.last;

    try {
      final process = await Process.start(
        interpreter,
        [scriptPath, ...args],
        environment: environment,
        workingDirectory: workingDirectory,
        runInShell: Platform.isWindows,
      );

      final outputCompleter = Completer<String>();
      final errorCompleter = Completer<String>();

      final outputBuffer = StringBuffer();
      final errorBuffer = StringBuffer();

      process.stdout.transform(utf8.decoder).listen(outputBuffer.write);
      process.stderr.transform(utf8.decoder).listen(errorBuffer.write);

      // 等待进程完成或超时
      final exitCode = await process.exitCode.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          process.kill();
          throw TimeoutException('Script execution timeout after $timeoutSeconds seconds');
        },
      );

      stopwatch.stop();

      return ScriptExecutionResult(
        scriptName: scriptName,
        scriptType: scriptType,
        success: exitCode == 0,
        output: outputBuffer.toString(),
        error: errorBuffer.toString(),
        exitCode: exitCode,
        duration: stopwatch.elapsed,
      );
    } on TimeoutException catch (e) {
      stopwatch.stop();
      return ScriptExecutionResult(
        scriptName: scriptName,
        scriptType: scriptType,
        success: false,
        output: '',
        error: e.message,
        exitCode: -1,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ScriptExecutionResult(
        scriptName: scriptName,
        scriptType: scriptType,
        success: false,
        output: '',
        error: e.toString(),
        exitCode: -1,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// 执行内联代码
  Future<ScriptExecutionResult> _executeCode({
    required String interpreter,
    required String code,
    Map<String, String>? environment,
    String? workingDirectory,
    required int timeoutSeconds,
    required String scriptType,
  }) async {
    final stopwatch = Stopwatch()..start();
    final scriptName = 'inline_$scriptType';

    try {
      final process = await Process.start(
        interpreter,
        ['-c', code],
        environment: environment,
        workingDirectory: workingDirectory,
        runInShell: Platform.isWindows,
      );

      final outputBuffer = StringBuffer();
      final errorBuffer = StringBuffer();

      process.stdout.transform(utf8.decoder).listen(outputBuffer.write);
      process.stderr.transform(utf8.decoder).listen(errorBuffer.write);

      final exitCode = await process.exitCode.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          process.kill();
          throw TimeoutException('Script execution timeout after $timeoutSeconds seconds');
        },
      );

      stopwatch.stop();

      return ScriptExecutionResult(
        scriptName: scriptName,
        scriptType: scriptType,
        success: exitCode == 0,
        output: outputBuffer.toString(),
        error: errorBuffer.toString(),
        exitCode: exitCode,
        duration: stopwatch.elapsed,
      );
    } on TimeoutException catch (e) {
      stopwatch.stop();
      return ScriptExecutionResult(
        scriptName: scriptName,
        scriptType: scriptType,
        success: false,
        output: '',
        error: e.message,
        exitCode: -1,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ScriptExecutionResult(
        scriptName: scriptName,
        scriptType: scriptType,
        success: false,
        output: '',
        error: e.toString(),
        exitCode: -1,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// 检查解释器是否可用
  Future<bool> checkInterpreter(String interpreter) async {
    try {
      final result = await Process.run(interpreter, ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 检查所有解释器
  Future<Map<String, bool>> checkAllInterpreters() async {
    return {
      'python': await checkInterpreter(pythonInterpreter),
      'node': await checkInterpreter(nodeInterpreter),
      'shell': await checkInterpreter(shellInterpreter),
    };
  }
}
