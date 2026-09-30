import 'package:flutter/material.dart';

import '../models/models.dart';

/// All of Sage's teaching text in one place:
/// - explainers: shown when a lightbulb button is tapped
/// - lessons: the Academy learning path
/// - tourSteps: the welcome tour on first launch
class GuideContent {
  GuideContent._();

  static const explainers = <String, Explainer>{
    'market_read': Explainer('How Sage reads the market', [
      'This card turns raw numbers into a plain sentence. I check three things: where the price sits compared with its recent averages (the trend), how stretched the latest move is (RSI), and how big the swings are (volatility).',
      'Price above its averages usually means buyers are in control. Below them, sellers are. Crossing back and forth means the market has not decided yet.',
    ], 'Tap a coin under the text to switch. The chart and the numbers below follow your choice.'),
    'mood': Explainer('What the mood score means', [
      'The score runs from 0 to 100 and is built from how the six major coins moved over the last 24 hours. Low means most coins are falling and people are nervous. High means most are rising and people are excited.',
      'The extremes are the useful part. When everyone is greedy, prices are often stretched and a pullback is more likely. When everyone is fearful, strong coins sometimes trade at a discount.',
    ], 'Treat mood like the weather: good to know before you go out, but it is not a buy or sell button.'),
    'candles': Explainer('Reading a candlestick chart', [
      'Each candle is one slice of time, like one hour. The thick body shows where the price opened and closed. Green means it closed higher than it opened; red means it closed lower.',
      'The thin lines above and below, called wicks, show the highest and lowest price in that slice. Long wicks mean the price was pushed hard in one direction and then rejected.',
      'The bars along the bottom are volume: how much was traded. A big move on big volume is more convincing than the same move on thin volume. The dashed brass line marks the latest price.',
    ], 'Hover or drag across the chart to read the open, high, low and close of any candle.'),
    'signals': Explainer('How the AI signals work', [
      'Our models (Random Forest, XGBoost and SVM) were trained on years of Binance price history using indicators such as RSI, MACD, Bollinger Bands, ATR and volume. They do not guess an exact price. They label the coming period as bullish, bearish or neutral.',
      'Confidence shows how sure the model is, based on patterns it has seen before. It is not a guarantee. A 90% bullish signal can still be wrong when news or a whale changes the picture.',
    ], 'Tap any signal to see the reasons behind it, then check them against the chart yourself.'),
    'rsi': Explainer('What RSI tells you', [
      'RSI (Relative Strength Index) compares the size of recent up-moves with recent down-moves and turns it into a number from 0 to 100.',
      'Above 70, the price has risen fast and may be stretched, so buying there is riskier. Below 30, it has fallen fast and sellers may be tiring. Between 30 and 70 is normal.',
    ], 'RSI can stay high for a long time in a strong trend. Use it as a warning light, not a trigger on its own.'),
    'volatility': Explainer('What volatility means', [
      'Volatility measures how much the price jumps from one candle to the next. We show it as the typical percentage move per candle.',
      'High volatility means bigger opportunities and bigger losses. When it is high, experienced traders buy smaller amounts and set wider stop-losses so normal noise does not knock them out.',
    ], 'Very quiet markets often come right before a big move in either direction.'),
    'portfolio': Explainer('Understanding your portfolio', [
      'Your average buy price is what you paid per coin on average. Profit or loss compares it with today\'s price. It only becomes real when you sell; until then it is "unrealised".',
      'The ring shows how your money is split. If one coin fills most of the ring, one bad day for that coin becomes a bad day for you.',
    ], 'Many investors keep any single coin under half of their portfolio.'),
    'alerts': Explainer('How alerts help', [
      'Crypto trades all day and night, and nobody can watch it all the time. An alert watches for you and taps you on the shoulder when a price crosses a level you picked.',
      'Good alerts are set calmly in advance: near a price you would like to buy at, or a level where you would want to take some profit.',
    ], 'Once an alert fires it switches itself off. Switch it back on from the Triggered list to re-arm it.'),
    'limits': Explainer('Stop-loss and take-profit', [
      'A stop-loss is the price where you admit a trade is not working and get out before the loss grows. A take-profit is the price where you lock in a gain instead of hoping for more.',
      'Setting both before you buy protects you from the two feelings that cost investors the most: hope when prices fall, and greed when they rise.',
    ], 'CryptoSense alerts you when a limit is reached. It never sells anything for you.'),
    'news': Explainer('Why news moves prices', [
      'Regulation, big company purchases, hacks and exchange problems can move the whole market within minutes. Each headline here is tagged with a sentiment: whether it is likely to push prices up, down, or neither.',
      'Markets often overreact to headlines, then settle. The first move is not always the real one.',
    ], 'Tap a story to read Sage\'s take on what it could mean for you.'),
    'whales': Explainer('What whales are', [
      'A whale is a wallet holding a very large amount of a coin. When whales move money, it can hint at what they plan to do next.',
      'Coins moving onto an exchange are often being prepared for sale, which can push prices down. Coins moving off an exchange into private wallets usually mean long-term holding. Wallet-to-wallet moves are mostly neutral.',
    ], 'One whale move means little. A steady stream in the same direction is worth noticing.'),
    'listings': Explainer('New coins and their risks', [
      'Newly listed coins can jump hundreds of percent in days and fall just as fast. Their prices are driven by hype and a small number of traders, so there is little history to judge them by.',
      'The risk meter combines how wildly the coin has moved, how thin its trading is, and how concentrated its supply is.',
    ], 'Only put in what you could lose completely, and set a stop-loss the moment you buy.'),
  };

  static const lessons = [
    Lesson(
      id: 'l1',
      title: 'How prices go up and down',
      level: 'Beginner',
      minutes: 4,
      icon: Icons.swap_vert_rounded,
      summary: 'Buyers, sellers, and why a price is just the last deal made.',
      paragraphs: [
        'A crypto price is simply the last price someone paid. On an exchange, buyers post the price they are willing to pay and sellers post the price they are willing to accept. When the two meet, a trade happens, and that becomes the new price.',
        'If more people want to buy than sell, buyers have to offer more to get their order filled, and the price climbs. If more people want to sell, sellers have to accept less, and the price falls. Every chart you see is a record of this tug of war.',
        'What makes people eager to buy or sell? News, fear, excitement, big holders moving money, and simple patterns that many traders watch at the same time. CryptoSense tracks all of these so you can see which side is winning.',
      ],
      takeaway: 'Price moves when one side, buyers or sellers, is more eager than the other.',
      askPrompt: 'Why do prices go up and down?',
    ),
    Lesson(
      id: 'l2',
      title: 'Reading candlesticks',
      level: 'Beginner',
      minutes: 5,
      icon: Icons.candlestick_chart_rounded,
      summary: 'The chart language traders use every day.',
      paragraphs: [
        'A candle shows four prices for one slice of time: where it opened, the highest point, the lowest point, and where it closed. The thick body connects the open and the close. Green means the close was higher; red means it was lower.',
        'The wicks tell a story. A long wick below the body means sellers pushed the price down, but buyers stepped in and pushed it back up. A long wick above means buyers tried to push higher and sellers pushed back.',
        'Look at candles in groups, not one at a time. Several tall green candles in a row show strong buying. Small candles with long wicks on both sides show indecision.',
      ],
      takeaway: 'Bodies show who won the time slice; wicks show where the fight happened.',
      askPrompt: 'How do I read candles on the chart?',
    ),
    Lesson(
      id: 'l3',
      title: 'Trends, support and resistance',
      level: 'Beginner',
      minutes: 6,
      icon: Icons.stacked_line_chart_rounded,
      summary: 'Spot the direction of the market and the levels where it tends to turn.',
      paragraphs: [
        'An uptrend is a series of higher highs and higher lows, like climbing stairs. A downtrend is the opposite: lower highs and lower lows. If you cannot see either, the market is moving sideways.',
        'Support is a price level where buyers have stepped in before, acting like a floor. Resistance is a level where sellers have appeared before, acting like a ceiling. The more times a level holds, the more people watch it.',
        'When the price breaks through resistance with strong volume, that old ceiling often becomes the new floor. A break without volume is more likely to fail.',
      ],
      takeaway: 'Trade with the trend, and pay attention when price reaches a level it has turned at before.',
      askPrompt: 'What are support and resistance?',
    ),
    Lesson(
      id: 'l4',
      title: 'Momentum and RSI',
      level: 'Intermediate',
      minutes: 5,
      icon: Icons.speed_rounded,
      summary: 'How fast is the price moving, and is it running out of breath?',
      paragraphs: [
        'Momentum is the speed of a move. A price can still be rising while its momentum slows down, a bit like a ball thrown upward that is about to stop.',
        'RSI measures momentum on a scale from 0 to 100. Above 70, the move is stretched upward. Below 30, it is stretched downward. These zones do not mean "sell now" or "buy now"; they mean "be careful chasing this move".',
        'A useful pattern is divergence: the price makes a new high but RSI makes a lower high. That shows the buying pressure behind the move is weakening.',
      ],
      takeaway: 'RSI tells you how tired a move is, not where it will end.',
      askPrompt: 'What is RSI?',
    ),
    Lesson(
      id: 'l5',
      title: 'Volatility and managing risk',
      level: 'Intermediate',
      minutes: 6,
      icon: Icons.shield_outlined,
      summary: 'How to size your trades so one mistake never hurts too much.',
      paragraphs: [
        'Crypto can move 10% in a day, which is normal here but extreme in most markets. Volatility is not good or bad; it simply decides how carefully you need to size your positions.',
        'A common rule is to risk only 1 to 2 percent of your total money on any single idea. With \$1,000 and a 2% rule, you are willing to lose \$20. If your stop-loss is 10% below your buy price, your position should be about \$200.',
        'Always choose your stop-loss before you buy, then work out the position size from it. Doing it the other way around is how small losses turn into big ones.',
      ],
      takeaway: 'Decide how much you can lose first; the position size follows from that.',
      askPrompt: 'How do I set a stop-loss?',
    ),
    Lesson(
      id: 'l6',
      title: 'Whales, news and hype',
      level: 'Intermediate',
      minutes: 5,
      icon: Icons.waves_rounded,
      summary: 'The outside forces that suddenly move the market.',
      paragraphs: [
        'Whales hold so much that their trades alone can move the price. Watching whether they send coins to exchanges (possible selling) or pull coins off exchanges (holding) gives early clues.',
        'News moves prices fast, and the first reaction is often too strong. Good traders wait for the chart to confirm the news before acting.',
        'Hype is the most dangerous force, especially with new coins. When everyone around you is talking about a coin that has already doubled, much of the easy gain is usually gone.',
      ],
      takeaway: 'Use whales and news as clues, and be most careful when excitement is highest.',
      askPrompt: 'What are whales?',
    ),
    Lesson(
      id: 'l7',
      title: 'Using CryptoSense day to day',
      level: 'Beginner',
      minutes: 4,
      icon: Icons.route_rounded,
      summary: 'A simple routine that ties every page together.',
      paragraphs: [
        'Start on Overview. Read Sage\'s summary and the market mood to understand the big picture, then check the chart and AI signals for the coins you care about.',
        'Next, scan News and Whale watch for anything unusual. If something big is happening, it usually shows up there first.',
        'Then look after your money. Keep your Portfolio up to date, make sure every coin has a stop-loss in Profit & loss limits, and set Alerts so you do not have to stare at the screen. Whenever something is unclear, tap a lightbulb or ask Sage.',
      ],
      takeaway: 'Big picture, then clues, then protection. Ten minutes a day is enough.',
      askPrompt: 'How do I use this app?',
    ),
  ];

  static const tourSteps = [
    (
      icon: Icons.auto_awesome_rounded,
      title: "Hi, I'm Sage",
      body:
          "I'll be your guide around CryptoSense. Wherever you see a lightbulb button, tap it and I'll explain that part in plain words.",
    ),
    (
      icon: Icons.space_dashboard_rounded,
      title: 'Start with the Overview',
      body:
          'The top card is my plain-language read of the coin you pick, next to the market mood. Below it you get a live candle chart, the AI signals and your watchlist.',
    ),
    (
      icon: Icons.shield_outlined,
      title: 'Protect your money',
      body:
          'Add your coins in Portfolio, then set a stop-loss and take-profit for each in Profit & loss limits. Alerts tell you the moment something important happens.',
    ),
    (
      icon: Icons.school_rounded,
      title: 'Discover and learn',
      body:
          'Whale watch, New listings and News show what is moving the market. New to crypto? The Academy explains how prices really move, one short lesson at a time. CryptoSense supports your decisions; it never trades for you.',
    ),
  ];
}
