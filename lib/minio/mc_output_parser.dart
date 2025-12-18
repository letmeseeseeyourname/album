/// 解析 mc 默认模式输出的速率
/// 输入示例: "D:\image\pexels-sanaan-3075993.jpg: 192.00 KiB / 2.42 MiB  9.74 KiB/s"
/// 返回: 速率（字节/秒）
class McOutputParser {

  /// 解析输出字符串，返回速率（字节/秒）
  /// 格式不正确时返回 0
  static int parseSpeed(String? output) {
    if (output == null || output.isEmpty) return 0;

    try {
      // 匹配速率: 数字 + 单位 + /s
      // 例如: 9.74 KiB/s, 1.5 MiB/s, 500 B/s
      final speedRegex = RegExp(r'([\d.]+)\s*(B|KB|KiB|MB|MiB|GB|GiB)/s', caseSensitive: false);
      final match = speedRegex.firstMatch(output);

      if (match == null) return 0;

      final value = double.tryParse(match.group(1) ?? '');
      if (value == null) return 0;

      final unit = (match.group(2) ?? 'B').toUpperCase();

      return _convertToBytes(value, unit);
    } catch (e) {
      return 0;
    }
  }

  /// 解析输出字符串，返回格式化的速率字符串
  /// 格式不正确时返回 "0 B/s"
  static String parseSpeedString(String? output) {
    if (output == null || output.isEmpty) return '0 B/s';

    try {
      final speedRegex = RegExp(r'([\d.]+\s*(B|KB|KiB|MB|MiB|GB|GiB)/s)', caseSensitive: false);
      final match = speedRegex.firstMatch(output);
      return match?.group(1) ?? '0 B/s';
    } catch (e) {
      return '0 B/s';
    }
  }

  /// 解析已传输大小和总大小
  /// 格式不正确时返回 {transferred: 0, total: 0}
  static Map<String, int> parseProgress(String? output) {
    final defaultResult = {'transferred': 0, 'total': 0};

    if (output == null || output.isEmpty) return defaultResult;

    try {
      // 匹配: 192.00 KiB / 2.42 MiB
      final progressRegex = RegExp(
        r'([\d.]+)\s*(B|KB|KiB|MB|MiB|GB|GiB)\s*/\s*([\d.]+)\s*(B|KB|KiB|MB|MiB|GB|GiB)',
        caseSensitive: false,
      );
      final match = progressRegex.firstMatch(output);

      if (match == null) return defaultResult;

      final transferredValue = double.tryParse(match.group(1) ?? '');
      final totalValue = double.tryParse(match.group(3) ?? '');

      if (transferredValue == null || totalValue == null) return defaultResult;

      final transferredUnit = (match.group(2) ?? 'B').toUpperCase();
      final totalUnit = (match.group(4) ?? 'B').toUpperCase();

      return {
        'transferred': _convertToBytes(transferredValue, transferredUnit),
        'total': _convertToBytes(totalValue, totalUnit),
      };
    } catch (e) {
      return defaultResult;
    }
  }

  /// 解析完整信息：已传输、总大小、速率、进度百分比
  /// 格式不正确时返回默认值（全为0）
  static McProgressInfo parse(String? output) {
    if (output == null || output.isEmpty) {
      return McProgressInfo(transferred: 0, total: 0, speed: 0, percent: 0);
    }

    try {
      final progress = parseProgress(output);
      final speed = parseSpeed(output);

      final transferred = progress['transferred'] ?? 0;
      final total = progress['total'] ?? 0;
      final percent = total > 0 ? (transferred / total * 100) : 0.0;

      return McProgressInfo(
        transferred: transferred,
        total: total,
        speed: speed,
        percent: percent,
      );
    } catch (e) {
      return McProgressInfo(transferred: 0, total: 0, speed: 0, percent: 0);
    }
  }

  /// 将大小值转换为字节
  static int _convertToBytes(double value, String unit) {
    switch (unit) {
      case 'B':
        return value.round();
      case 'KB':
      case 'KIB':
        return (value * 1024).round();
      case 'MB':
      case 'MIB':
        return (value * 1024 * 1024).round();
      case 'GB':
      case 'GIB':
        return (value * 1024 * 1024 * 1024).round();
      case 'TB':
      case 'TIB':
        return (value * 1024 * 1024 * 1024 * 1024).round();
      default:
        return value.round();
    }
  }

  /// 格式化字节为可读字符串
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KiB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MiB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GiB';
  }

  /// 格式化速率为可读字符串
  static String formatSpeed(int bytesPerSecond) {
    return '${formatBytes(bytesPerSecond)}/s';
  }
}

/// 进度信息
class McProgressInfo {
  final int transferred;  // 已传输字节
  final int total;        // 总字节
  final int speed;        // 速率（字节/秒）
  final double percent;   // 进度百分比

  McProgressInfo({
    required this.transferred,
    required this.total,
    required this.speed,
    required this.percent,
  });

  String get formattedTransferred => McOutputParser.formatBytes(transferred);
  String get formattedTotal => McOutputParser.formatBytes(total);
  String get formattedSpeed => McOutputParser.formatSpeed(speed);
  String get formattedPercent => '${percent.toStringAsFixed(1)}%';

  @override
  String toString() {
    return 'McProgressInfo(transferred: $formattedTransferred, total: $formattedTotal, speed: $formattedSpeed, percent: $formattedPercent)';
  }
}