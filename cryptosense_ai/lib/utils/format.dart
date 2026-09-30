import 'package:intl/intl.dart' show DateFormat, NumberFormat;

/// Small helpers that turn numbers and dates into friendly text.
class Fmt {
  Fmt._();

  static final _usd0 = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  static final _usd2 = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  /// $67,284 / $148.30 / $0.5214
  static String usd(double v) {
    final a = v.abs();
    if (a >= 1000) return _usd0.format(v);
    if (a >= 1) return _usd2.format(v);
    return '${v < 0 ? '-' : ''}\$${a.toStringAsFixed(4)}';
  }

  /// $1.8B, $420M
  static String compact(double v) => '\$${NumberFormat.compact().format(v)}';

  /// +2.34% / -1.20%
  static String pct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

  /// Coin amounts: 1,240 / 1.60 / 0.1200
  static String coin(double v) {
    if (v >= 100) return NumberFormat('#,##0').format(v);
    if (v >= 1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(4);
  }

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
  }

  static String clock(DateTime t) => DateFormat('HH:mm:ss').format(t);
}
