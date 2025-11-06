import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LogUtil {
  static const String _logDirName = 'log';
  static const String _logFilePrefix = 'app_log_';
  static const int _maxLogFiles = 5;
  static File? _currentLogFile;

  /// Get the log directory, creating it if it doesn't exist.
  static Future<Directory> _getLogDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${baseDir.path}/$_logDirName');
    if (!(await logDir.exists())) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  /// Get the current log file, rotate if needed.
  static Future<File> _getLogFile() async {
    if (_currentLogFile != null) return _currentLogFile!;
    final dir = await _getLogDir();
    final logFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(_logFilePrefix))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    // Remove old files if over max
    if (logFiles.length >= _maxLogFiles) {
      logFiles.sublist(0, logFiles.length - _maxLogFiles + 1).forEach((file) {
        file.deleteSync();
      });
    }

    // Use latest log file if exists and less than 1 day old, else create new
    File logFile;
    if (logFiles.isNotEmpty) {
      final last = logFiles.last;
      final lastModified = last.lastModifiedSync();
      final now = DateTime.now();
      if (now.difference(lastModified).inDays < 1) {
        logFile = last;
      } else {
        logFile = File('${dir.path}/$_logFilePrefix${_formattedDate(now)}.txt');
      }
    } else {
      logFile = File('${dir.path}/$_logFilePrefix${_formattedDate(DateTime.now())}.txt');
    }

    _currentLogFile = logFile;
    if (!(await logFile.exists())) await logFile.create();
    return logFile;
  }

  static String _formattedDate(DateTime dateTime) =>
      DateFormat('yyyyMMdd_HHmmss').format(dateTime);

  /// Log a message with timestamp and caller function name to file.
  static Future<void> log(String message, {String? functionName}) async {
    final now = DateTime.now();
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now);
    final caller = functionName ?? _getCallerName();
    final logLine = '[$formattedTime][$caller] $message\n';
    debugPrint(logLine);

    final file = await _getLogFile();
    await file.writeAsString(logLine, mode: FileMode.append, flush: true);
  }

  /// Try to extract calling function name from stack trace.
  static String _getCallerName() {
    final stack = StackTrace.current.toString().split('\n');
    if (stack.length > 2) {
      final line = stack[2];
      final match = RegExp(r'#2\s+([^\s]+)').firstMatch(line);
      if (match != null && match.groupCount > 0) {
        return match.group(1)!;
      }
    }
    return 'unknown';
  }

  /// Get all log files in the log directory
  static Future<List<File>> getLogFiles() async {
    final dir = await _getLogDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(_logFilePrefix))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}