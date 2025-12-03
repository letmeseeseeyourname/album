class DateFormaterManager {
 /// 解析并标准化日期字符串
 ///
 /// 支持的格式：
 /// - "2025-11-27 10:57:51:143" (毫秒用冒号分隔 - 服务端非标准格式)
 /// - "2025-11-27 10:57:51.143" (标准毫秒格式)
 /// - "2025-11-27 10:57:51" (无毫秒)
 /// - "2025-1-7 10:57:51" (月/日不补零)
 /// - "2025-11-27" (仅日期)
 ///
 /// 返回 ISO 8601 格式: "2025-11-27T10:57:51" 或 "2025-11-27T10:57:51.143"
 static String pad(String s) {
  if (s.isEmpty) throw FormatException('Empty date string');

  final trimmed = s.trim();

  // 🆕 格式1: 带毫秒且毫秒用冒号分隔 "yyyy-M-d HH:mm:ss:SSS"
  final withColonMillis = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{2}):(\d{2}):(\d{2}):(\d{1,3})$'
  ).firstMatch(trimmed);
  if (withColonMillis != null) {
   final y = withColonMillis.group(1)!;
   final mo = withColonMillis.group(2)!.padLeft(2, '0');
   final d = withColonMillis.group(3)!.padLeft(2, '0');
   final h = withColonMillis.group(4)!;
   final mi = withColonMillis.group(5)!;
   final se = withColonMillis.group(6)!;
   final ms = withColonMillis.group(7)!.padRight(3, '0'); // 毫秒补齐到3位
   return '$y-$mo-${d}T$h:$mi:$se.$ms';
  }

  // 🆕 格式2: 带毫秒且毫秒用点号分隔 "yyyy-M-d HH:mm:ss.SSS"
  final withDotMillis = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{2}):(\d{2}):(\d{2})\.(\d{1,3})$'
  ).firstMatch(trimmed);
  if (withDotMillis != null) {
   final y = withDotMillis.group(1)!;
   final mo = withDotMillis.group(2)!.padLeft(2, '0');
   final d = withDotMillis.group(3)!.padLeft(2, '0');
   final h = withDotMillis.group(4)!;
   final mi = withDotMillis.group(5)!;
   final se = withDotMillis.group(6)!;
   final ms = withDotMillis.group(7)!.padRight(3, '0');
   return '$y-$mo-${d}T$h:$mi:$se.$ms';
  }

  // 格式3: 无毫秒 "yyyy-M-d HH:mm:ss" (原有逻辑)
  final noMillis = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{2}):(\d{2}):(\d{2})$'
  ).firstMatch(trimmed);
  if (noMillis != null) {
   final y = noMillis.group(1)!;
   final mo = noMillis.group(2)!.padLeft(2, '0');
   final d = noMillis.group(3)!.padLeft(2, '0');
   final h = noMillis.group(4)!;
   final mi = noMillis.group(5)!;
   final se = noMillis.group(6)!;
   return '$y-$mo-${d}T$h:$mi:$se';
  }

  // 🆕 格式4: 仅日期 "yyyy-M-d"
  final dateOnly = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})$'
  ).firstMatch(trimmed);
  if (dateOnly != null) {
   final y = dateOnly.group(1)!;
   final mo = dateOnly.group(2)!.padLeft(2, '0');
   final d = dateOnly.group(3)!.padLeft(2, '0');
   return '$y-$mo-${d}T00:00:00';
  }

  // 🆕 格式5: 已经是 ISO 格式 "yyyy-MM-ddTHH:mm:ss"
  final isoFormat = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
  ).firstMatch(trimmed);
  if (isoFormat != null) {
   return trimmed; // 已经是标准格式，直接返回
  }

  throw FormatException('Bad date: $s');
 }

 /// 🆕 安全解析日期，解析失败返回 null 而不是抛出异常
 static DateTime? safeParse(String? s) {
  if (s == null || s.trim().isEmpty) return null;

  try {
   final normalized = pad(s);
   return DateTime.parse(normalized);
  } catch (e) {
   print('⚠️ 日期解析失败: $s, 错误: $e');
   return null;
  }
 }
}