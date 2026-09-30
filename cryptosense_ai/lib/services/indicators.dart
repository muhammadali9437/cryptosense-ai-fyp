import 'dart:math';

/// Technical indicators computed in the browser from candle closes.
/// (The ML backend uses the same ideas with TA-Lib; these are for display.)
class Indicators {
  Indicators._();

  /// Relative Strength Index (0..100). Above 70 = stretched up, below 30 = stretched down.
  static double rsi(List<double> closes, [int period = 14]) {
    if (closes.length <= period) return 50;
    double gain = 0, loss = 0;
    for (var i = closes.length - period; i < closes.length; i++) {
      final d = closes[i] - closes[i - 1];
      if (d >= 0) {
        gain += d;
      } else {
        loss -= d;
      }
    }
    if (loss == 0) return 100;
    final rs = (gain / period) / (loss / period);
    return 100 - 100 / (1 + rs);
  }

  /// Simple moving average of the last [n] values.
  static double sma(List<double> values, int n) {
    if (values.isEmpty) return 0;
    final slice = values.length < n ? values : values.sublist(values.length - n);
    return slice.reduce((a, b) => a + b) / slice.length;
  }

  /// Standard deviation of candle-to-candle % returns.
  static double volatility(List<double> closes) {
    if (closes.length < 3) return 0;
    final r = <double>[];
    for (var i = 1; i < closes.length; i++) {
      r.add((closes[i] - closes[i - 1]) / closes[i - 1] * 100);
    }
    final mean = r.reduce((a, b) => a + b) / r.length;
    final variance = r.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / r.length;
    return sqrt(variance);
  }

  /// Longer candles naturally move more, so volatility is scaled to "per hour" terms.
  static double volScale(String interval) => switch (interval) {
        '15m' => 0.5,
        '4h' => 2.0,
        '1d' => 4.5,
        _ => 1.0,
      };

  static String volWord(double scaledVol) =>
      scaledVol > 0.9 ? 'Wild' : scaledVol > 0.4 ? 'Moderate' : 'Calm';
}
