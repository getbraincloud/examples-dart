/// Formats an integer with comma thousand-separators when its absolute
/// value reaches 1,000 — e.g. `withCommas(1234)` → `"1,234"`,
/// `withCommas(950)` → `"950"`, `withCommas(-12345)` → `"-12,345"`.
String withCommas(int value) {
  if (value.abs() < 1000) return '$value';
  return value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
