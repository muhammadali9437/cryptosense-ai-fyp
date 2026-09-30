import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import '../services/app_state.dart';
import '../services/market_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pop.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import '../widgets/tour.dart';
import 'academy_screen.dart';
import 'alerts_screen.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'limits_screen.dart';
import 'listings_screen.dart';
import 'news_screen.dart';
import 'portfolio_screen.dart';
import 'whale_screen.dart';

/// App frame: sidebar (or drawer on small screens) + top bar + current page.
/// Also listens to prices and pops a notification when an alert or limit fires.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final MarketService _market;
  late final AppState _app;

  static final List<WidgetBuilder> _pages = [
    (_) => const DashboardScreen(),
    (_) => const PortfolioScreen(),
    (_) => const AlertsScreen(),
    (_) => const LimitsScreen(),
    (_) => const NewsScreen(),
    (_) => const WhaleScreen(),
    (_) => const ListingsScreen(),
    (_) => const AcademyScreen(),
    (_) => const ChatScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _market = context.market;
    _app = context.app;
    _market.addListener(_checkAlerts);
    // Messages from the backend (alerts / stop-loss / take-profit) and save errors
    _app.onNotify = (message) {
      if (mounted) toast(context, message, color: AppColors.warn, icon: Icons.notifications_active_rounded);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_app.tourSeen) showTour(context);
    });
  }

  @override
  void dispose() {
    _market.removeListener(_checkAlerts);
    _app.onNotify = null;
    super.dispose();
  }

  void _checkAlerts() {
    final messages = _app.evaluate(_market.tickers);
    if (messages.isEmpty || !mounted) return;
    final text = messages.length == 1
        ? messages.first
        : '${messages.first} (+${messages.length - 1} more in Alerts)';
    toast(context, text, color: AppColors.warn, icon: Icons.notifications_active_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;

    void select(int i) {
      _app.go(i);
      if (!wide) _scaffoldKey.currentState?.closeDrawer();
    }

    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) => Scaffold(
        key: _scaffoldKey,
        drawer: wide ? null : Drawer(width: 256, child: Sidebar(onSelect: select)),
        body: Row(
          children: [
            if (wide) Sidebar(onSelect: select),
            Expanded(
              child: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: TopBar(
                      showMenu: !wide,
                      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      onHelp: () => showTour(context),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 260),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_app.page),
                        child: _pages[_app.page](context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}