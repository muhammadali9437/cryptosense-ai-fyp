import 'dart:math';

import '../models/models.dart';

/// Demo data used until the FastAPI backend is connected (step 2).
/// Live prices and candles come from Binance directly; everything here
/// (signals, news, whales, new listings) will be replaced by backend calls.
class MockData {
  MockData._();

  static final _rng = Random(7);

  static const names = {
    'BTCUSDT': 'Bitcoin',
    'ETHUSDT': 'Ethereum',
    'BNBUSDT': 'BNB',
    'SOLUSDT': 'Solana',
    'XRPUSDT': 'XRP',
    'ADAUSDT': 'Cardano',
  };

  static const seedPrices = {
    'BTCUSDT': 67284.0,
    'ETHUSDT': 3506.0,
    'BNBUSDT': 592.4,
    'SOLUSDT': 148.3,
    'XRPUSDT': 0.5214,
    'ADAUSDT': 0.4478,
  };

  static const seedChange = {
    'BTCUSDT': 2.34,
    'ETHUSDT': 1.8,
    'BNBUSDT': 0.4,
    'SOLUSDT': -1.9,
    'XRPUSDT': 0.9,
    'ADAUSDT': -0.6,
  };

  static const seedVolume = {
    'BTCUSDT': 1.84e9,
    'ETHUSDT': 9.6e8,
    'BNBUSDT': 1.9e8,
    'SOLUSDT': 4.1e8,
    'XRPUSDT': 2.2e8,
    'ADAUSDT': 9.4e7,
  };

  /// Random walk used for sparklines before live data arrives.
  static List<double> walk(double start, int n, double stepPct) {
    final out = <double>[start];
    for (var i = 1; i < n; i++) {
      out.add(out.last * (1 + (_rng.nextDouble() - 0.5) * stepPct));
    }
    return out;
  }

  static Duration intervalDuration(String interval) => switch (interval) {
        '15m' => const Duration(minutes: 15),
        '4h' => const Duration(hours: 4),
        '1d' => const Duration(days: 1),
        _ => const Duration(hours: 1),
      };

  /// Fake candles that end exactly at [lastPrice], so the chart matches the ticker.
  static List<Candle> candles(double lastPrice, String interval, {int count = 90}) {
    final step = intervalDuration(interval);
    final swing = switch (interval) { '15m' => 0.004, '4h' => 0.014, '1d' => 0.03, _ => 0.008 };
    final closes = <double>[lastPrice];
    for (var i = 1; i < count; i++) {
      closes.add(closes.last / (1 + (_rng.nextDouble() - 0.48) * swing));
    }
    final ordered = closes.reversed.toList();
    final now = DateTime.now();
    return List.generate(count, (i) {
      final close = ordered[i];
      final open = i == 0 ? close * (1 - (_rng.nextDouble() - 0.5) * swing) : ordered[i - 1];
      final top = max(open, close) * (1 + _rng.nextDouble() * swing * 0.4);
      final bottom = min(open, close) * (1 - _rng.nextDouble() * swing * 0.4);
      return Candle(
        time: now.subtract(step * (count - 1 - i)),
        open: open,
        high: top,
        low: bottom,
        close: close,
        volume: 200 + _rng.nextDouble() * 800,
      );
    });
  }

  // ---------------------------------------------------------------- signals
  static const signals = [
    AiSignal(
      symbol: 'BTCUSDT',
      trend: Trend.bullish,
      model: 'Random Forest',
      confidence: 0.94,
      horizon: 'Next 24 hours',
      reasons: [
        'Price is above its 20- and 50-period moving averages.',
        'MACD crossed above its signal line six hours ago.',
        'Buying volume is 18% higher than the weekly average.',
      ],
    ),
    AiSignal(
      symbol: 'ETHUSDT',
      trend: Trend.bullish,
      model: 'XGBoost',
      confidence: 0.87,
      horizon: 'Next 24 hours',
      reasons: [
        'Higher lows on the 4-hour chart for three days in a row.',
        'RSI is 61: rising, but not yet stretched.',
        'Bollinger Bands are widening upward after a quiet period.',
      ],
    ),
    AiSignal(
      symbol: 'BNBUSDT',
      trend: Trend.neutral,
      model: 'SVM',
      confidence: 0.71,
      horizon: 'Next 24 hours',
      reasons: [
        'Price is moving inside a tight range with no clear breakout.',
        'Volume is flat compared with last week.',
        'Momentum indicators disagree with each other.',
      ],
    ),
    AiSignal(
      symbol: 'SOLUSDT',
      trend: Trend.bearish,
      model: 'Random Forest',
      confidence: 0.82,
      horizon: 'Next 24 hours',
      reasons: [
        'Price fell below its 50-period average yesterday.',
        'Selling volume spiked during the last two drops.',
        'ATR (average range) is rising, a sign of nervous trading.',
      ],
    ),
    AiSignal(
      symbol: 'XRPUSDT',
      trend: Trend.neutral,
      model: 'XGBoost',
      confidence: 0.64,
      horizon: 'Next 24 hours',
      reasons: [
        'Price is pinned between clear support and resistance levels.',
        'News-driven volume is fading.',
        'Low model confidence: mixed signals across indicators.',
      ],
    ),
    AiSignal(
      symbol: 'ADAUSDT',
      trend: Trend.bearish,
      model: 'SVM',
      confidence: 0.69,
      horizon: 'Next 24 hours',
      reasons: [
        'Lower highs on the daily chart for two weeks.',
        'MACD is below zero and falling.',
        'Buy orders are thinning out below the current price.',
      ],
    ),
  ];

  static AiSignal? signalFor(String symbol) {
    for (final s in signals) {
      if (s.symbol == symbol) return s;
    }
    return null;
  }

  // ------------------------------------------------------------------- news
  static final List<NewsItem> news = _buildNews();

  static List<NewsItem> _buildNews() {
    final now = DateTime.now();
    return [
      NewsItem(
        title: 'Spot Bitcoin funds record a third straight week of inflows',
        source: 'Block Daily',
        time: now.subtract(const Duration(minutes: 35)),
        sentiment: Trend.bullish,
        coins: const ['BTC'],
        summary:
            'Investment funds that hold Bitcoin directly took in fresh money for the third week running, led by large asset managers.',
        sageTake:
            'Steady inflows mean new money is buying and holding Bitcoin, which tends to support the price over weeks. It does not tell you what happens tomorrow.',
      ),
      NewsItem(
        title: 'Ethereum network upgrade date confirmed for next quarter',
        source: 'Chain Ledger',
        time: now.subtract(const Duration(hours: 2)),
        sentiment: Trend.bullish,
        coins: const ['ETH'],
        summary:
            'Core developers agreed on a target date for the next upgrade, which aims to lower fees for applications built on Ethereum.',
        sageTake:
            'Upgrades often create excitement before they happen. Prices sometimes rise into the event and cool off after it, so watch for a "sell the news" move.',
      ),
      NewsItem(
        title: 'Major exchange pauses withdrawals for emergency maintenance',
        source: 'Market Wire',
        time: now.subtract(const Duration(hours: 3)),
        sentiment: Trend.bearish,
        coins: const ['BTC', 'ETH', 'SOL'],
        summary:
            'A large exchange temporarily stopped withdrawals, saying it needed to fix a wallet issue. Deposits and trading continue.',
        sageTake:
            'Withdrawal pauses make people nervous because of past exchange collapses. Usually it is routine, but it is a good reminder not to keep everything on one exchange.',
      ),
      NewsItem(
        title: 'Regulators publish draft rules for crypto trading platforms',
        source: 'Policy Brief',
        time: now.subtract(const Duration(hours: 5)),
        sentiment: Trend.neutral,
        coins: const ['BTC'],
        summary:
            'The draft sets out licensing and reporting requirements for exchanges. Public comments are open for sixty days.',
        sageTake:
            'Clear rules can bring in cautious investors over time, but drafts often change. The market usually waits for the final version before reacting strongly.',
      ),
      NewsItem(
        title: 'Solana network sees a brief slowdown during a traffic spike',
        source: 'Chain Ledger',
        time: now.subtract(const Duration(hours: 7)),
        sentiment: Trend.bearish,
        coins: const ['SOL'],
        summary:
            'Transactions slowed for about forty minutes as demand surged. Validators restored normal speed without a restart.',
        sageTake:
            'Reliability problems tend to hit the price for a day or two. If slowdowns keep repeating, that becomes a bigger concern than a single event.',
      ),
      NewsItem(
        title: 'BNB Chain transaction count hits a new monthly high',
        source: 'Block Daily',
        time: now.subtract(const Duration(hours: 9)),
        sentiment: Trend.bullish,
        coins: const ['BNB'],
        summary:
            'Daily transactions reached their highest level this month, driven by gaming and payments apps.',
        sageTake:
            'More real usage is a healthy sign. It supports the coin in the long run, even if the price doesn\'t react immediately.',
      ),
      NewsItem(
        title: 'XRP volume jumps as traders wait for a court update',
        source: 'Market Wire',
        time: now.subtract(const Duration(hours: 12)),
        sentiment: Trend.neutral,
        coins: const ['XRP'],
        summary:
            'Trading volume doubled ahead of an expected ruling, while the price stayed inside its weekly range.',
        sageTake:
            'High volume with a flat price means buyers and sellers are evenly matched. The ruling could break the range in either direction, so this is a time for small positions.',
      ),
    ];
  }

  // ----------------------------------------------------------------- whales
  static final _wr = Random(11);
  static int _whaleId = 0;
  static const _exchanges = ['Binance', 'Coinbase', 'Kraken', 'OKX', 'Bybit'];

  static WhaleTx randomWhale({DateTime? at}) {
    final pick = _wr.nextInt(4);
    final (coin, price, lo, hi) = switch (pick) {
      0 => ('BTC', 67284.0, 120.0, 950.0),
      1 => ('ETH', 3506.0, 1800.0, 16000.0),
      2 => ('SOL', 148.3, 40000.0, 260000.0),
      _ => ('USDT', 1.0, 15e6, 120e6),
    };
    final amount = lo + _wr.nextDouble() * (hi - lo);
    final flow = WhaleFlow.values[_wr.nextInt(3)];
    final exchange = _exchanges[_wr.nextInt(_exchanges.length)];
    return WhaleTx(
      id: 'w${_whaleId++}',
      coin: coin,
      amount: amount,
      usd: amount * price,
      from: flow == WhaleFlow.fromExchange ? exchange : 'Unknown wallet',
      to: flow == WhaleFlow.toExchange ? exchange : 'Unknown wallet',
      time: at ?? DateTime.now(),
      flow: flow,
    );
  }

  static final List<WhaleTx> whaleSeed = _buildWhales();

  static List<WhaleTx> _buildWhales() {
    final now = DateTime.now();
    return List.generate(12, (i) => randomWhale(at: now.subtract(Duration(minutes: 3 + i * 6))));
  }

  // ----------------------------------------------------------- new listings
  static final List<NewListing> listings = _buildListings();

  static List<NewListing> _buildListings() {
    final now = DateTime.now();
    return [
      NewListing(
        symbol: 'NRA',
        name: 'Neura Protocol',
        category: 'AI',
        listedAt: now.subtract(const Duration(days: 2)),
        changeSinceListing: 184,
        volume24h: 4.2e7,
        risk: 2,
        note: 'Huge first-week jump on AI hype. Most of the supply is still held by the team and early backers.',
      ),
      NewListing(
        symbol: 'ORBT',
        name: 'Orbital Pay',
        category: 'Payments',
        listedAt: now.subtract(const Duration(days: 5)),
        changeSinceListing: -31,
        volume24h: 1.8e7,
        risk: 2,
        note: 'Sold off right after listing, a common pattern when early investors cash out.',
      ),
      NewListing(
        symbol: 'LUMA',
        name: 'Lumen Layer',
        category: 'Layer 2',
        listedAt: now.subtract(const Duration(days: 8)),
        changeSinceListing: 22,
        volume24h: 6.4e7,
        risk: 1,
        note: 'Steadier volume spread across several exchanges. Still young, but calmer than most new listings.',
      ),
      NewListing(
        symbol: 'KTG',
        name: 'Kite Games',
        category: 'Gaming',
        listedAt: now.subtract(const Duration(days: 11)),
        changeSinceListing: 6,
        volume24h: 9.5e6,
        risk: 2,
        note: 'Thin trading means one large order can move the price a lot in either direction.',
      ),
      NewListing(
        symbol: 'VRDE',
        name: 'Verde Grid',
        category: 'Energy',
        listedAt: now.subtract(const Duration(days: 14)),
        changeSinceListing: -12,
        volume24h: 2.7e7,
        risk: 1,
        note: 'Drifting lower on falling volume. Interest may be fading after the listing buzz.',
      ),
      NewListing(
        symbol: 'QRZ',
        name: 'Quartz DEX',
        category: 'DeFi',
        listedAt: now.subtract(const Duration(days: 20)),
        changeSinceListing: 48,
        volume24h: 8.8e7,
        risk: 1,
        note: 'Growing real usage on its exchange. Supply is more widely spread than most new coins.',
      ),
    ];
  }
}
