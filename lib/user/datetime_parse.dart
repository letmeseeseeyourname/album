class DateFormaterManager {
 static  String pad(String s) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{2}):(\d{2}):(\d{2})$').firstMatch(s);
  if (m == null) throw FormatException('Bad date: $s');
  final y = m.group(1)!;
  final mo = m.group(2)!.padLeft(2, '0');
  final d = m.group(3)!.padLeft(2, '0');
  final h = m.group(4)!, mi = m.group(5)!, se = m.group(6)!;
  return '$y-$mo-${d}T$h:$mi:$se';
}
}