# CryptoSense AI — Flutter web frontend

Final Year Project, University of Kotli AJK (Data Science, 2022–2026)
Muhammad Ali (2022-uok-04526) and Ilyas Hussain (2022-uok-04530)
Supervisor: Ms. Syeda Seerat Zahra Naqvi

This is the frontend of **CryptoSense AI: An AI-Based Real-Time Cryptocurrency Market Analytics System**.
It covers every module in the proposal (live market data, AI market-state signals, portfolio and P&L,
P&L limits, alerts, news, chatbot) plus three trader tools: whale watch, new listings, and an Academy.
A guide called **Sage** explains every part of the app in plain language.

CryptoSense is a decision-support tool. It never places trades.

---

## 1. How to run it

You need Flutter 3.24 or newer (`flutter --version`) and Chrome.

```bash
# 1. Unzip, then open a terminal inside the cryptosense_ai folder
cd cryptosense_ai

# 2. Generate the web platform files (keeps our lib/ and pubspec.yaml)
flutter create . --platforms web

# 3. Delete the sample test that flutter create adds (it refers to a counter app)
#    Windows: del test\widget_test.dart     Mac/Linux: rm test/widget_test.dart

# 4. Download packages and check the code
flutter pub get
flutter analyze

# 5. Run
flutter run -d chrome
```

To build a deployable site: `flutter build web` (output in `build/web`).

---

## 2. What is live and what is demo

| Feature | Source now | Source after backend (step 2) |
|---|---|---|
| Prices, 24h change, volume, high/low | **Live** — Binance WebSocket | Same |
| Candle chart (15m, 1h, 4h, 1d) | **Live** — Binance REST klines | Same |
| RSI, volatility, Sage's market read | **Live** — computed in the browser | Same |
| AI signals (bullish/bearish/neutral) | Demo | FastAPI + Random Forest / XGBoost / SVM |
| News with sentiment | Demo | NewsAPI or CryptoPanic + sentiment model |
| Whale transfers | Demo (simulated feed) | Whale Alert API / Etherscan |
| New listings | Demo | Binance announcements / CoinGecko "recently added" |
| Portfolio, alerts, limits | In memory | PostgreSQL through FastAPI |
| Ask Sage chat | Rule-based with live numbers | FastAPI chatbot endpoint (LLM) |

If Binance can't be reached (no internet, blocked network), the app switches to simulated
prices automatically and the badge in the top bar changes from **Live** to **Demo data**.
Every demo section shows a small note saying so.

---

## 3. Every file and what it does

```
cryptosense_ai/
├── pubspec.yaml
├── analysis_options.yaml
└── lib/
    ├── main.dart
    ├── theme/      app_colors.dart, app_theme.dart
    ├── utils/      format.dart
    ├── models/     models.dart
    ├── services/   app_scope.dart, market_service.dart, app_state.dart, indicators.dart,
    │               sage_brain.dart, guide_content.dart, mock_data.dart
    ├── widgets/    tappable.dart, buttons.dart, bits.dart, panel.dart, pop.dart, explain.dart,
    │               candle_chart.dart, mini_charts.dart, sidebar.dart, top_bar.dart, tour.dart
    └── screens/    shell.dart, dashboard_screen.dart, portfolio_screen.dart, alerts_screen.dart,
                    limits_screen.dart, news_screen.dart, whale_screen.dart, listings_screen.dart,
                    academy_screen.dart, chat_screen.dart
```

### Project files
- **pubspec.yaml** — project name and packages: `google_fonts` (Sora + DM Sans), `http` (REST calls),
  `web_socket_channel` (live price stream), `intl` (number/date formatting).
- **analysis_options.yaml** — turns on the standard Flutter lint rules for `flutter analyze`.

### lib/main.dart
Entry point. Creates the two shared services (`MarketService` and `AppState`), starts the live
price stream, wraps the app in `AppScope` so every screen can reach them, applies the theme and
opens the `Shell`.

### theme/
- **app_colors.dart** — the palette. Deep plum background ("night trading desk"), brass as the
  brand accent, orchid for Sage, mint for price up, coral for price down, blue for neutral, amber
  for warnings. Also a `fade()` helper for transparent versions of a color.
- **app_theme.dart** — `AppText` (three text roles: `display` = Sora for headings, `body` = DM Sans,
  `number` = DM Sans with tabular figures so changing prices don't wobble) and `AppTheme.dark()`,
  which styles inputs, sliders, tooltips, progress bars and the drawer.

### utils/
- **format.dart** — `Fmt` turns numbers into friendly text: `$67,284`, `$1.8B`, `+2.34%`,
  `12 min ago`, `20:00:23`.

### models/
- **models.dart** — every data shape in one file: `Ticker` (live 24h snapshot), `Candle` (OHLCV),
  `AiSignal` (model, trend, confidence, reasons), `Holding` (amount, average buy, stop-loss,
  take-profit), `PriceAlert`, `NewsItem`, `WhaleTx` + `WhaleFlow` (with plain-language meaning),
  `NewListing`, `Lesson`, `Explainer`, `ChatMessage`.

### services/ (logic, no UI)
- **app_scope.dart** — an `InheritedWidget` that shares the services. Any widget can write
  `context.market` or `context.app`.
- **market_service.dart** — real-time data. Connects to Binance's public WebSocket
  (`wss://stream.binance.com:9443`) for BTC, ETH, BNB, SOL, XRP and ADA; fetches candles from
  `https://api.binance.com/api/v3/klines`; falls back to a simulated feed if Binance can't be
  reached; limits screen redraws to about once a second; computes the market mood score (0–100).
- **app_state.dart** — everything the user creates: current page, portfolio holdings, P&L limits,
  alerts, finished lessons and the chat. `evaluate()` runs on every price update and returns
  messages when an alert or a stop-loss/take-profit is hit.
- **indicators.dart** — RSI (14), simple moving average and volatility, calculated from candle
  closes in the browser.
- **sage_brain.dart** — Sage's voice. `marketRead()` turns trend (price vs 20/50 averages), RSI
  and volatility into a plain-English paragraph. `reply()` answers chat questions using live
  prices and the user's portfolio. In step 2 this calls the backend chatbot instead.
- **guide_content.dart** — all teaching text: the lightbulb explanations (candles, RSI, signals,
  whales, limits, …), the seven Academy lessons, and the four-step welcome tour.
- **mock_data.dart** — demo data used until the backend exists: AI signals with reasons, news,
  whale transfers, new listings, starting prices and a candle generator for offline mode.

### widgets/ (reusable UI pieces)
- **tappable.dart** — the one interaction primitive behind every custom button, row and chip:
  hover, keyboard focus (Tab then Enter/Space), a soft press-in effect, and respect for the
  system "reduce motion" setting.
- **buttons.dart** — `AppButton` (brass primary or outlined ghost) and `SegmentPills`
  (timeframe/filter selector).
- **bits.dart** — small pieces: `TrendBadge`, `ChangeText` (green/red %), `CoinAvatar`, `Tag`,
  `RiskMeter` (three bars), `DemoNote`, `FieldLabel`, `CoinChoice` (coin picker chips).
- **panel.dart** — `Panel` (card with title, subtitle, action and lightbulb), `PageBody`
  (scrollable page with max width), `Split` (two columns on desktop, stacked on phones),
  `TileGrid` (responsive card grid).
- **pop.dart** — the popup system: `showPop` (blurred background, gentle spring-in),
  `PopCard` (popup layout), `confirmPop` (yes/no), and `toast` (small notification).
- **explain.dart** — `SageAvatar`, the lightbulb `ExplainButton`, `showExplainer` (Sage's
  explanation popup) and `TipBox`.
- **candle_chart.dart** — custom-painted candlestick chart with volume bars, price axis,
  dashed live-price line and hover/drag readout of open, high, low and close.
- **mini_charts.dart** — `Sparkline` (watchlist), `DonutChart` (portfolio allocation) and
  `MoodGauge` (half-circle market mood meter).
- **sidebar.dart** — the list of pages (`navEntries`) and the left navigation: logo, grouped
  links, alert badge, and an "Ask Sage" card.
- **top_bar.dart** — page title and description, BTC/ETH price chips, the pulsing Live / Demo
  data badge, a clock, and the button that replays the tour.
- **tour.dart** — the welcome tour. Opens on first launch; Sage introduces the app in four steps.

### screens/ (one file per page)
- **shell.dart** — app frame. Sidebar on wide screens, drawer on phones, top bar, animated page
  switching. Listens to prices and shows a notification when an alert or limit fires.
- **dashboard_screen.dart** — Overview. Sage's market read with a coin picker and the mood
  gauge; the candle chart with 15m/1h/4h/1d; 24h high/low, RSI and volatility; AI signal list
  (tap for the reasons); watchlist with sparklines; whale and new-listing snapshots.
- **portfolio_screen.dart** — total value, profit or loss, allocation ring, Sage's diversification
  comment, holdings list, "Add holding" popup and remove confirmation.
- **alerts_screen.dart** — create alerts (price above, price below, big 24h move), switch them on
  or off, delete them, see the Triggered history.
- **limits_screen.dart** — per coin: stop-loss and take-profit sliders with the exact trigger price
  and money at stake, plus a live bar showing where the position sits between the two.
- **news_screen.dart** — headlines filtered by sentiment; tap for the full summary and Sage's take.
- **whale_screen.dart** — last-hour exchange inflow vs outflow with Sage's reading, and a live
  feed of large transfers (filterable). Tap one to learn what it may mean.
- **listings_screen.dart** — new coins with change since listing, volume, category and a risk
  meter, plus a "Before you buy" checklist.
- **academy_screen.dart** — seven-lesson learning path (how prices move, candles, trends, RSI,
  risk, whales/news, daily routine) with progress, a lesson reader, "Mark as done" and
  "Ask Sage about this".
- **chat_screen.dart** — Ask Sage: chat bubbles, typing indicator, suggestion chips and input.

---

## 4. Design notes

- Palette: plum `#120E1A`, panel `#1B1526`, brass `#E3B55B`, orchid `#9C6ADE`, mint `#5FD4A0`,
  coral `#F2706B`. Green and red appear only when they mean price direction.
- Type: Sora for headings and Sage's voice, DM Sans for everything else.
- The memorable element is Sage: a written market read at the top of the Overview, a lightbulb
  on every panel, a first-run tour, the Academy and the chat.
- Popups blur the page behind them and spring in; buttons press in slightly; everything works
  with the keyboard and respects "reduce motion".
- Responsive: sidebar becomes a drawer below 980 px; two-column sections stack below 1080 px.

## 5. Proposal note

The proposal lists React.js or Streamlit for the frontend. Update the Tools and Technologies
section to "Flutter (web)" so the document matches this implementation.
