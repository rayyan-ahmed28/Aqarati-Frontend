/// The running build's version (kept in step with pubspec.yaml `version`). The version gate compares
/// it with the server's minimum supported version from GET /app/config.
const kAppVersion = '1.0.0';

/// Compares dotted versions numerically ("1.10.0" > "1.9.3"). Missing parts count as zero.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}
