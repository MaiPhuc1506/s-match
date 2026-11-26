/// Formats a VND amount without changing the underlying numeric value.
String formatVietnameseVnd(num amount) {
  final digits = amount.round().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$grouped VND';
}
