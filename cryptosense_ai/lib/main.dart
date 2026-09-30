import 'package:flutter/material.dart';

import 'screens/shell.dart';
import 'services/api_service.dart';
import 'services/app_scope.dart';
import 'services/app_state.dart';
import 'services/market_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CryptoSenseApp());
}

/// Root widget. Creates the shared services and makes them available to every
/// screen through [AppScope]:
/// - MarketService: live prices straight from Binance
/// - AppState + ApiService: everything that comes from / is saved to the FastAPI backend
class CryptoSenseApp extends StatefulWidget {
  const CryptoSenseApp({super.key});

  @override
  State<CryptoSenseApp> createState() => _CryptoSenseAppState();
}

class _CryptoSenseAppState extends State<CryptoSenseApp> {
  final market = MarketService();
  final app = AppState(ApiService()); // ApiService = connection to the backend

  @override
  void initState() {
    super.initState();
    market.start(); // live prices from Binance
    app.init(); // connect to the backend (falls back to demo mode if it's offline)
  }

  @override
  void dispose() {
    market.dispose();
    app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      market: market,
      app: app,
      child: MaterialApp(
        title: 'CryptoSense AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const Shell(),
      ),
    );
  }
}