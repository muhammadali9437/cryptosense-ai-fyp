import 'package:flutter/widgets.dart';

import 'app_state.dart';
import 'market_service.dart';

/// Makes the two shared services reachable from any widget:
///   context.market  -> live prices and candles
///   context.app     -> portfolio, alerts, chat, navigation
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.market,
    required this.app,
    required super.child,
  });

  final MarketService market;
  final AppState app;

  static AppScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      market != oldWidget.market || app != oldWidget.app;
}

extension ScopeX on BuildContext {
  MarketService get market => AppScope.of(this).market;
  AppState get app => AppScope.of(this).app;
}
