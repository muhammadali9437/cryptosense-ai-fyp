import 'package:flutter/widgets.dart';

import '../utils/format.dart';

/// Every data shape the frontend works with lives in this one file.

enum Trend { bullish, bearish, neutral }

extension TrendLabel on Trend {
  String get label => switch (this) {
        Trend.bullish => 'Bullish',
        Trend.bearish => 'Bearish',
        Trend.neutral => 'Neutral',
      };
}

/// Live 24h market snapshot of one trading pair (e.g. BTCUSDT).
class Ticker {
  const Ticker({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
    required this.quoteVolume,
    required this.high,
    required this.low,
    this.history = const [],
  });

  final String symbol;
  final String name;
  final double price;
  final double changePct; // 24h change in %
  final double quoteVolume; // 24h volume in USDT
  final double high; // 24h high
  final double low; // 24h low
  final List<double> history; // recent prices for the sparkline

  String get base => symbol.replaceAll('USDT', '');

  Ticker copyWith({
    double? price,
    double? changePct,
    double? quoteVolume,
    double? high,
    double? low,
    List<double>? history,
  }) =>
      Ticker(
        symbol: symbol,
        name: name,
        price: price ?? this.price,
        changePct: changePct ?? this.changePct,
        quoteVolume: quoteVolume ?? this.quoteVolume,
        high: high ?? this.high,
        low: low ?? this.low,
        history: history ?? this.history,
      );
}

/// One OHLCV candle.
class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime time;
  final double open, high, low, close, volume;

  bool get isUp => close >= open;
}

/// Output of the AI models (XGBoost + LightGBM + GRU ensemble) for one coin.
class AiSignal {
  const AiSignal({
    required this.symbol,
    required this.trend,
    required this.model,
    required this.confidence,
    required this.horizon,
    required this.reasons,
  });

  final String symbol;
  final Trend trend;
  final String model;
  final double confidence; // 0..1
  final String horizon;
  final List<String> reasons; // explainability: why the model decided this

  String get base => symbol.replaceAll('USDT', '');
}

/// A coin the user owns, plus their personal profit/loss limits.
class Holding {
  Holding({
    required this.symbol,
    required this.amount,
    required this.avgBuy,
    this.stopLossPct,
    this.takeProfitPct,
  });

  final String symbol;
  double amount;
  double avgBuy;
  double? stopLossPct; // alert when down this many %
  double? takeProfitPct; // alert when up this many %
  bool limitFired = false;

  String get base => symbol.replaceAll('USDT', '');
}

enum AlertKind { above, below, move }

class PriceAlert {
  PriceAlert({
    required this.id,
    required this.symbol,
    required this.kind,
    required this.value,
    this.active = true,
    this.triggeredAt,
  });

  final String id;
  final String symbol;
  final AlertKind kind;
  final double value;
  bool active;
  DateTime? triggeredAt;

  String get base => symbol.replaceAll('USDT', '');

  String describe() => switch (kind) {
        AlertKind.above => '$base rises above ${Fmt.usd(value)}',
        AlertKind.below => '$base falls below ${Fmt.usd(value)}',
        AlertKind.move => '$base moves more than ${value.toStringAsFixed(0)}% in 24h',
      };
}

class NewsItem {
  const NewsItem({
    required this.title,
    required this.source,
    required this.time,
    required this.sentiment,
    required this.summary,
    required this.sageTake,
    required this.coins,
  });

  final String title;
  final String source;
  final DateTime time;
  final Trend sentiment;
  final String summary;
  final String sageTake;
  final List<String> coins;
}

enum WhaleFlow { toExchange, fromExchange, walletToWallet }

extension WhaleFlowText on WhaleFlow {
  String get label => switch (this) {
        WhaleFlow.toExchange => 'Moved onto an exchange',
        WhaleFlow.fromExchange => 'Moved off an exchange',
        WhaleFlow.walletToWallet => 'Moved between wallets',
      };

  String get meaning => switch (this) {
        WhaleFlow.toExchange =>
          'Coins sent to an exchange are often being prepared for sale. Several of these in a row can put pressure on the price.',
        WhaleFlow.fromExchange =>
          'Coins pulled off an exchange usually go into long-term storage. That shrinks the supply available to sell.',
        WhaleFlow.walletToWallet =>
          'Transfers between private wallets are usually neutral: reorganising funds, custody changes or over-the-counter deals.',
      };
}

class WhaleTx {
  const WhaleTx({
    required this.id,
    required this.coin,
    required this.amount,
    required this.usd,
    required this.from,
    required this.to,
    required this.time,
    required this.flow,
  });

  final String id;
  final String coin;
  final double amount;
  final double usd;
  final String from;
  final String to;
  final DateTime time;
  final WhaleFlow flow;
}

class NewListing {
  const NewListing({
    required this.symbol,
    required this.name,
    required this.category,
    required this.listedAt,
    required this.changeSinceListing,
    required this.volume24h,
    required this.risk,
    required this.note,
  });

  final String symbol;
  final String name;
  final String category;
  final DateTime listedAt;
  final double changeSinceListing;
  final double volume24h;
  final int risk; // 0 = lower, 1 = medium, 2 = high
  final String note;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.level,
    required this.minutes,
    required this.summary,
    required this.paragraphs,
    required this.takeaway,
    required this.askPrompt,
    required this.icon,
  });

  final String id;
  final String title;
  final String level;
  final int minutes;
  final String summary;
  final List<String> paragraphs;
  final String takeaway;
  final String askPrompt; // question sent to Sage from the lesson
  final IconData icon;
}

/// A plain-language explanation shown when the user taps a lightbulb button.
class Explainer {
  const Explainer(this.title, this.paragraphs, [this.tip]);

  final String title;
  final List<String> paragraphs;
  final String? tip;
}

/// A document Sage used to answer (from the backend RAG search).
class ChatSource {
  const ChatSource({required this.title, required this.kind, this.url = ''});

  final String title;
  final String kind; // academy, news, signal, app_guide, methodology
  final String url;
}

class ChatMessage {
  ChatMessage({required this.text, required this.fromUser, DateTime? time, this.sources = const []})
      : time = time ?? DateTime.now();

  final String text;
  final bool fromUser;
  final DateTime time;
  final List<ChatSource> sources; // shown under Sage's answer
}