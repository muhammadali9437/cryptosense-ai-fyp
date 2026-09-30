import '../models/models.dart';
import '../utils/format.dart';
import 'app_state.dart';
import 'indicators.dart';
import 'market_service.dart';

/// Sage is the human-like guide of CryptoSense.
///
/// For now Sage answers with rules + live numbers from [MarketService].
/// In the backend step, [reply] will call the FastAPI chatbot endpoint
/// (OpenAI / LLM) and send it the same live context.
class SageBrain {
  SageBrain._();

  static const greeting =
      "Hi, I'm Sage. I watch the market with you and explain it in plain words. "
      'Ask me how a coin is doing, what an indicator means, how your portfolio looks, '
      'or how to use any part of CryptoSense.';

  static const suggestions = [
    'How is Bitcoin doing?',
    'How is my portfolio?',
    'What is RSI?',
    'Why do prices go up and down?',
    'How do I set a stop-loss?',
    'Are new coins safe to buy?',
    'What are whales?',
    'How do I use this app?',
  ];

  /// The plain-language "market read" shown at the top of the Overview.
  static String marketRead(Ticker t, List<Candle> candles, String interval) {
    if (candles.length < 20) return 'Loading enough history to read ${t.name}...';
    final closes = candles.map((c) => c.close).toList();
    final rsi = Indicators.rsi(closes);
    final fast = Indicators.sma(closes, 20);
    final slow = Indicators.sma(closes, 50);
    final vol = Indicators.volatility(closes) / Indicators.volScale(interval);

    final String trend;
    if (t.price > fast && fast > slow) {
      trend = '${t.name} is climbing. The price is holding above its short and medium averages, so buyers are in charge for now.';
    } else if (t.price < fast && fast < slow) {
      trend = '${t.name} is sliding. The price sits below its short and medium averages, so sellers have the upper hand.';
    } else {
      trend = '${t.name} is moving sideways, crossing back and forth over its averages while the market makes up its mind.';
    }

    final String heat;
    if (rsi >= 70) {
      heat = 'RSI is ${rsi.round()}, so the move is stretched and a pullback would be normal.';
    } else if (rsi <= 30) {
      heat = 'RSI is ${rsi.round()}: it has fallen fast and sellers may be tiring, but wait for the chart to turn before buying.';
    } else {
      heat = 'RSI is ${rsi.round()}, comfortably in the middle, so neither side is exhausted.';
    }

    final String swing;
    if (vol > 0.9) {
      swing = 'Swings are large right now, so if you trade, use smaller amounts.';
    } else if (vol > 0.4) {
      swing = 'Volatility is moderate.';
    } else {
      swing = 'Volatility is low, and quiet stretches like this often come before a bigger move.';
    }

    return '$trend $heat $swing';
  }

  /// Chat answer for a free-text question.
  static String reply(String question, MarketService market, AppState app) {
    final q = question.toLowerCase();
    bool has(List<String> words) => words.any(q.contains);

    if (RegExp(r'^(hi+|hello|hey|salam|assalam|aoa)\b').hasMatch(q)) {
      return 'Hello! Ask me about any coin (try "How is ETH doing?"), about indicators like RSI, '
          'or about your own portfolio and limits.';
    }
    if (has(['thank', 'shukriya'])) {
      return 'Anytime. Markets change fast, so come back whenever something looks confusing.';
    }

    if (has(['my portfolio', 'my coins', 'my holdings', 'am i up', 'am i down', 'my profit', 'my loss'])) {
      return _portfolio(market, app);
    }

    for (final t in market.tickers.values) {
      final pattern = RegExp('\\b(${t.base.toLowerCase()}|${t.name.toLowerCase()})\\b');
      if (pattern.hasMatch(q)) return _coin(t);
    }

    if (has(['should i buy', 'should i sell', 'invest', 'buy now', 'sell now', 'good time', 'which coin'])) {
      return "I can't tell you what to buy or sell. CryptoSense supports your decisions; it isn't a financial advisor. "
          'What I can do is help you check the basics first. Is the trend up on the chart? Is RSI stretched above 70? '
          'What do the AI signals say, and how confident are they? Is there big news or whale activity? '
          'Most important of all: have you picked your stop-loss and decided how much you could afford to lose? '
          "Tell me the coin and I'll walk through it with you.";
    }
    if (has(['rsi', 'overbought', 'oversold'])) {
      return 'RSI (Relative Strength Index) scores recent price moves from 0 to 100. Above 70 means the coin has risen fast '
          'and may be stretched. Below 30 means it has dropped fast and sellers may be running out of steam. '
          'In a strong trend RSI can stay high for days, so treat it as a warning light rather than a buy or sell button. '
          "You'll find the live RSI under the chart on the Overview page.";
    }
    if (has(['candle', 'wick', 'chart'])) {
      return 'Each candle is one slice of time. The thick body runs from the opening price to the closing price: '
          'green if it closed higher, red if it closed lower. The thin wicks show the highest and lowest prices in that slice. '
          'A long lower wick means sellers pushed the price down but buyers stepped in. '
          'On the Overview chart you can hover over any candle to read its numbers.';
    }
    if (has(['whale'])) {
      return 'Whales are wallets holding huge amounts of a coin. When they move coins onto an exchange, it often means they may sell. '
          'When they move coins off an exchange, it usually means they plan to hold. One move means little; '
          'a steady stream in one direction is worth noticing. Open Whale watch to see the latest big transfers.';
    }
    if (has(['new coin', 'listing', 'listed', 'new token', 'meme', 'new coins'])) {
      return 'New coins can double in a day and halve the next. They have little history, thin trading, and often a few wallets '
          'holding most of the supply. If you try one, use money you could lose completely, buy a small amount, and set a '
          'stop-loss straight away. The New listings page rates each one from lower to high risk.';
    }
    if (has(['stop', 'take profit', 'take-profit', 'limit'])) {
      return 'A stop-loss is the price where you accept a trade is not working and get out before the loss grows. '
          'A take-profit is where you lock in a gain. To set them, open Profit & loss limits, pick a percentage for each coin, '
          'and tap Save limits. CryptoSense will alert you the moment a limit is reached. It never sells for you.';
    }
    if (has(['alert', 'notify', 'notification'])) {
      return 'Open Alerts and tap Create alert. Choose a coin, then whether you want to hear when it rises above a price, '
          'falls below a price, or moves a lot in 24 hours. Once it fires it switches itself off, and you can re-arm it anytime.';
    }
    if (has(['volatil', 'risk', 'safe'])) {
      return 'Volatility is how much the price jumps around. Higher volatility means bigger possible gains and losses. '
          'A simple rule many traders follow is to risk only 1 to 2 percent of their total money on any single trade. '
          'For example, with \$1,000 and a 10% stop-loss, a \$200 position risks about \$20.';
    }
    if (has(['signal', 'model', 'random forest', 'xgboost', 'svm', 'confidence', 'predict']) ||
        RegExp(r'\bai\b').hasMatch(q)) {
      return 'Our AI models (Random Forest, XGBoost and SVM) learned from years of Binance price history. '
          'They classify the next period as bullish, bearish or neutral and give a confidence score. '
          'They do not predict an exact price, and a high confidence can still be wrong. '
          'Tap any signal on the Overview page to see the reasons behind it.';
    }
    if (has(['news', 'headline'])) {
      return 'News can move prices in minutes, especially regulation, hacks and big company purchases. '
          'The first reaction is often too strong, and prices settle later. On the News page every story is tagged '
          "bullish, bearish or neutral, and you can tap it to read my take.";
    }
    if (has(['up and down', 'go up', 'go down', 'why is', 'why does', 'why do', 'price move', 'market move', 'pump', 'dump', 'crash', 'flow'])) {
      return 'A price is simply the last deal between a buyer and a seller. When more people want to buy than sell, buyers '
          'have to pay more and the price rises. When more want to sell, they have to accept less and it falls. '
          'News, fear, excitement and whales change how eager each side is. The Academy has a short lesson on this, '
          'called "How prices go up and down".';
    }
    if (has(['how do i use', 'how to use', 'where do i', 'start', 'help', 'what can you', 'guide'])) {
      return 'Here is a simple daily routine. First, open Overview and read my summary and the market mood. '
          'Second, check the AI signals and the chart for coins you care about. Third, glance at News and Whale watch '
          'for anything unusual. Fourth, update your Portfolio and make sure every coin has a stop-loss. '
          'Finally, set Alerts so you do not have to watch the screen all day. The Academy teaches each part step by step.';
    }

    return "I'm not sure I understood that yet. I can help with coin prices and trends (try \"How is SOL doing?\"), "
        'indicators like RSI and candlesticks, your portfolio and limits, whales, new listings, news, '
        'and how to use CryptoSense.';
  }

  static String _coin(Ticker t) {
    final dir = t.changePct >= 0 ? 'up' : 'down';
    final range = t.high - t.low;
    final pos = range <= 0 ? 0.5 : (t.price - t.low) / range;
    final where = pos > 0.8
        ? "It's trading near the top of today's range, so buyers are in control, but buying right at the highs is risky."
        : pos < 0.2
            ? "It's near the bottom of today's range, so sellers have the upper hand for now."
            : "It's in the middle of today's range, so neither side is dominating.";
    return '${t.name} is at ${Fmt.usd(t.price)}, $dir ${t.changePct.abs().toStringAsFixed(2)}% over 24 hours. '
        'Today it has traded between ${Fmt.usd(t.low)} and ${Fmt.usd(t.high)}. $where '
        'Pick ${t.base} on the Overview page to see my full read with RSI and volatility.';
  }

  static String _portfolio(MarketService m, AppState app) {
    if (app.holdings.isEmpty) {
      return "You haven't added any coins yet. Open Portfolio and tap Add holding, then I can tell you how you're doing.";
    }
    final value = app.portfolioValue(m.tickers);
    final cost = app.portfolioCost();
    final pnl = value - cost;
    final pct = cost == 0 ? 0.0 : pnl / cost * 100;

    Holding? top;
    var topValue = 0.0;
    for (final h in app.holdings) {
      final v = h.amount * (m.tickers[h.symbol]?.price ?? h.avgBuy);
      if (v > topValue) {
        topValue = v;
        top = h;
      }
    }
    final share = value == 0 ? 0.0 : topValue / value * 100;

    final result = pnl >= 0
        ? "You're up ${Fmt.usd(pnl)} (${Fmt.pct(pct)}) overall."
        : "You're down ${Fmt.usd(pnl.abs())} (${Fmt.pct(pct)}) overall.";
    var text = 'Your portfolio is worth ${Fmt.usd(value)} right now. $result';
    if (top != null) text += ' ${top.base} is your biggest position at ${share.round()}% of the total.';
    if (share > 50) text += ' That is a lot in one coin. If it has a bad week, your whole portfolio feels it.';
    return text;
  }
}
