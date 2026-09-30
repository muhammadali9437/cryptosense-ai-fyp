import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/panel.dart';
import '../widgets/pop.dart';

/// Alerts: create price alerts, switch them on/off, see what already fired.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final market = context.market;
    return ListenableBuilder(
      listenable: Listenable.merge([app, market]),
      builder: (context, _) {
        final watching = app.alerts.where((a) => a.triggeredAt == null).toList();
        final fired = app.alerts.where((a) => a.triggeredAt != null).toList()
          ..sort((a, b) => b.triggeredAt!.compareTo(a.triggeredAt!));

        return PageBody(maxWidth: 980, children: [
          Panel(
            title: 'Watching for you',
            subtitle: 'CryptoSense checks prices every second and notifies you when a condition is met.',
            explain: 'alerts',
            trailing: AppButton(
              label: 'Create alert',
              icon: Icons.add_alert_rounded,
              compact: true,
              onTap: () => showCreateAlert(context),
            ),
            child: watching.isEmpty
                ? _EmptyAlerts(onCreate: () => showCreateAlert(context))
                : Column(children: [for (final a in watching) _AlertRow(alert: a)]),
          ),
          Panel(
            title: 'Triggered',
            subtitle: 'Alerts that already fired. Switch one on again to re-arm it.',
            child: fired.isEmpty
                ? Text('Nothing has fired yet. When it does, you will see it here and get a notification.',
                    style: AppText.body(14, color: AppColors.muted))
                : Column(children: [for (final a in fired) _AlertRow(alert: a)]),
          ),
        ]);
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final PriceAlert alert;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final price = context.market.tickers[alert.symbol]?.price;
    final icon = switch (alert.kind) {
      AlertKind.above => Icons.trending_up_rounded,
      AlertKind.below => Icons.trending_down_rounded,
      AlertKind.move => Icons.swap_vert_rounded,
    };
    final color = switch (alert.kind) {
      AlertKind.above => AppColors.bull,
      AlertKind.below => AppColors.bear,
      AlertKind.move => AppColors.calm,
    };
    final status = alert.triggeredAt != null
        ? 'Triggered ${Fmt.ago(alert.triggeredAt!)}'
        : alert.active
            ? 'Watching. ${alert.base} is ${price == null ? '...' : Fmt.usd(price)} now'
            : 'Paused';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          CoinAvatar(alert.base, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('When ${alert.describe()}',
                          style: AppText.body(14.5, w: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(status,
                    style: AppText.body(12.5,
                        color: alert.triggeredAt != null ? AppColors.warn : AppColors.muted)),
              ],
            ),
          ),
          Tooltip(
            message: alert.active ? 'Pause alert' : 'Switch alert on',
            child: Switch(
              value: alert.active,
              onChanged: (_) => app.toggleAlert(alert.id),
              activeTrackColor: AppColors.brass,
              inactiveTrackColor: AppColors.line,
              thumbColor: const WidgetStatePropertyAll(AppColors.text),
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
          IconButton(
            tooltip: 'Delete alert',
            onPressed: () {
              app.removeAlert(alert.id);
              toast(context, 'Alert deleted', color: AppColors.muted, icon: Icons.delete_outline_rounded);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Icon(Icons.notifications_none_rounded, size: 40, color: AppColors.faint),
            const SizedBox(height: 10),
            Text('No alerts yet. Create one and CryptoSense will watch the price for you.',
                textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.muted)),
            const SizedBox(height: 14),
            AppButton(label: 'Create alert', icon: Icons.add_alert_rounded, onTap: onCreate),
          ],
        ),
      );
}

// ------------------------------------------------------------- create popup
Future<void> showCreateAlert(BuildContext context) =>
    showPop<void>(context, child: const _CreateAlertForm());

class _CreateAlertForm extends StatefulWidget {
  const _CreateAlertForm();

  @override
  State<_CreateAlertForm> createState() => _CreateAlertFormState();
}

class _CreateAlertFormState extends State<_CreateAlertForm> {
  String _symbol = 'BTCUSDT';
  AlertKind _kind = AlertKind.above;
  final _value = TextEditingController();
  String? _error;

  static const _kindLabels = {
    'above': 'Rises above',
    'below': 'Falls below',
    'move': 'Moves a lot',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_value.text.isEmpty) _suggest();
  }

  /// Pre-fill a sensible value: +5% / -5% of the current price, or a 5% move.
  void _suggest() {
    final p = context.market.ticker(_symbol).price;
    final v = switch (_kind) {
      AlertKind.above => p * 1.05,
      AlertKind.below => p * 0.95,
      AlertKind.move => 5.0,
    };
    _value.text = _kind == AlertKind.move
        ? v.toStringAsFixed(0)
        : v >= 100
            ? v.toStringAsFixed(0)
            : v >= 1
                ? v.toStringAsFixed(2)
                : v.toStringAsFixed(4);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  double? get _parsed => double.tryParse(_value.text.replaceAll(',', '').trim());

  void _save() {
    final v = _parsed;
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter a number greater than zero.');
      return;
    }
    context.app.addAlert(_symbol, _kind, v);
    final preview = PriceAlert(id: '', symbol: _symbol, kind: _kind, value: v).describe();
    toast(context, 'Alert created: when $preview');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.market.ticker(_symbol);
    final v = _parsed;
    final preview = v == null || v <= 0
        ? null
        : PriceAlert(id: '', symbol: _symbol, kind: _kind, value: v).describe();

    return PopCard(
      title: 'Create an alert',
      subtitle: '${t.base} is ${Fmt.usd(t.price)} right now',
      icon: Icons.add_alert_rounded,
      actions: [
        AppButton(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          color: AppColors.muted,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Create alert', icon: Icons.check_rounded, onTap: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Coin'),
          CoinChoice(
            selected: _symbol,
            onChanged: (s) => setState(() {
              _symbol = s;
              _suggest();
            }),
          ),
          const FieldLabel('Tell me when the price'),
          SegmentPills(
            options: const ['above', 'below', 'move'],
            labels: _kindLabels,
            selected: _kind.name,
            onChanged: (k) => setState(() {
              _kind = AlertKind.values.byName(k);
              _suggest();
            }),
          ),
          FieldLabel(_kind == AlertKind.move ? 'Percent move in 24 hours' : 'Price (USD)'),
          TextField(
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.number(15, w: FontWeight.w500),
            decoration: InputDecoration(
              prefixText: _kind == AlertKind.move ? null : '\$ ',
              suffixText: _kind == AlertKind.move ? '%' : null,
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!, style: AppText.body(13.5, color: AppColors.bear))
          else if (preview != null)
            Text("You'll be notified when $preview.", style: AppText.body(14, color: AppColors.muted)),
        ],
      ),
    );
  }
}
