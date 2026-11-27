/// Formats a money value from the API (num, String or null) as "₹123.45".
String formatRupees(dynamic value) {
  final n = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  return '₹${n.toStringAsFixed(2)}';
}
