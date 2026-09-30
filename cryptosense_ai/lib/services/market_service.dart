import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';
import 'mock_data.dart';

/// Real-time market data.
///
/// 1. Tries Binance's public WebSocket (no API key needed) for live 24h tickers.
/// 2. If Binance can't be reached, switches to a simulated "demo" feed so the
///    UI keeps working (useful during a viva with bad Wi-Fi).
/// 3. Candles come from Binance REST /api/v3/klines, with a demo fallback.
class MarketService extends ChangeNotifier {
  static const symbols = ['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT', 'XRPUSDT', 'ADAUSDT'];

  final Map<String, Ticker> tickers = {};
  bool isLive = false;
  DateTime lastUpdate = DateTime.now();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _demoTimer;
  final _rng = Random();
  final _gotLive = <String>{};
  bool _notifyQueued = false;
  bool _disposed = false;

  Ticker ticker(String symbol) => tickers[symbol]!;

  Future<void> start() async {
    for (final s in symbols) {
      final p = MockData.seedPrices[s]!;
      tickers[s] = Ticker(
        symbol: s,
        name: MockData.names[s]!,
        price: p,
        changePct: MockData.seedChange[s]!,
        quoteVolume: MockData.seedVolume[s]!,
        high: p * 1.021,
        low: p * 0.978,
        history: MockData.walk(p, 40, 0.004),
      );
    }
    notifyListeners();
    await _connectLive();
  }

  Future<void> _connectLive() async {
    WebSocketChannel? channel;
    try {
      final streams = symbols.map((s) => '${s.toLowerCase()}@ticker').join('/');
      channel = WebSocketChannel.connect(
        Uri.parse('wss://stream.binance.com:9443/stream?streams=$streams'),
      );
      await channel.ready.timeout(const Duration(seconds: 6));
      if (_disposed) {
        channel.sink.close();
        return;
      }
      _channel = channel;
      _sub = channel.stream.listen(_onMessage, onError: (_) => _startDemo(), onDone: _startDemo);
      isLive = true;
      _queueNotify();
    } catch (_) {
      channel?.sink.close();
      _startDemo();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final d = msg['data'] as Map<String, dynamic>;
      final symbol = d['s'] as String;
      final old = tickers[symbol];
      if (old == null) return;

      final price = double.parse(d['c'] as String);
      List<double> history;
      if (_gotLive.add(symbol)) {
        // First live tick: rescale the demo sparkline so it ends at the real price.
        final ratio = price / old.history.last;
        history = old.history.map((v) => v * ratio).toList();
      } else {
        history = [...old.history, price];
        if (history.length > 60) history.removeAt(0);
      }

      tickers[symbol] = old.copyWith(
        price: price,
        changePct: double.parse(d['P'] as String),
        quoteVolume: double.parse(d['q'] as String),
        high: double.parse(d['h'] as String),
        low: double.parse(d['l'] as String),
        history: history,
      );
      lastUpdate = DateTime.now();
      _queueNotify();
    } catch (_) {
      // Ignore malformed messages.
    }
  }

  /// Binance sends several messages per second; redraw at most ~once a second.
  void _queueNotify() {
    if (_notifyQueued || _disposed) return;
    _notifyQueued = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      _notifyQueued = false;
      if (!_disposed) notifyListeners();
    });
  }

  void _startDemo() {
    if (_disposed) return;
    isLive = false;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _demoTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => _tickDemo());
    _queueNotify();
  }

  void _tickDemo() {
    for (final s in symbols) {
      final t = tickers[s]!;
      final price = t.price * (1 + (_rng.nextDouble() - 0.5) * 0.0024);
      final history = [...t.history, price];
      if (history.length > 60) history.removeAt(0);
      tickers[s] = t.copyWith(
        price: price,
        changePct: t.changePct + (price / t.price - 1) * 100,
        high: max(t.high, price),
        low: min(t.low, price),
        history: history,
      );
    }
    lastUpdate = DateTime.now();
    notifyListeners();
  }

  /// OHLCV candles for the chart. [interval] is one of 15m, 1h, 4h, 1d.
  Future<List<Candle>> candles(String symbol, String interval) async {
    try {
      final uri = Uri.parse(
          'https://api.binance.com/api/v3/klines?symbol=$symbol&interval=$interval&limit=90');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body) as List<dynamic>;
        return raw.map((k) {
          final row = k as List<dynamic>;
          return Candle(
            time: DateTime.fromMillisecondsSinceEpoch(row[0] as int),
            open: double.parse(row[1] as String),
            high: double.parse(row[2] as String),
            low: double.parse(row[3] as String),
            close: double.parse(row[4] as String),
            volume: double.parse(row[5] as String),
          );
        }).toList();
      }
    } catch (_) {
      // fall through to demo candles
    }
    return MockData.candles(tickers[symbol]?.price ?? 100, interval);
  }

  /// 0..100 mood score from the average 24h move of the tracked coins.
  double get mood {
    if (tickers.isEmpty) return 50;
    final avg = tickers.values.map((t) => t.changePct).reduce((a, b) => a + b) / tickers.length;
    return (50 + avg * 7).clamp(5, 95).toDouble();
  }

  static String moodLabel(double m) => m < 25
      ? 'Fearful'
      : m < 45
          ? 'Cautious'
          : m < 56
              ? 'Balanced'
              : m < 75
                  ? 'Confident'
                  : 'Greedy';

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _channel?.sink.close();
    _demoTimer?.cancel();
    super.dispose();
  }
}
