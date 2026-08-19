import 'dart:math';

final _rng = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${_rng.nextInt(99999)}';

String two(int v) => v.toString().padLeft(2, '0');

String formatDate(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';

String formatTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String formatDateTime(DateTime d) => '${formatDate(d)}  ${formatTime(d)}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int nextPowerOfTwo(int n) {
  var p = 1;
  while (p < n) {
    p *= 2;
  }
  return p;
}

String groupLetter(int index) {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if (index < letters.length) return letters[index];
  return '${index + 1}';
}
