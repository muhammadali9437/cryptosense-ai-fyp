import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_scope.dart';
import '../services/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/explain.dart';
import '../widgets/mini_charts.dart';
import '../widgets/panel.dart';
import '../widgets/pop.dart';

/// Portfolio: total value, profit/loss, allocation ring and the holdings list.
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final market = context.market;
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([market, app]),
      builder: (context, _) {
        final tickers = market.tickers;
        final value = app.portfolioValue(tickers);
        final cost = app.portfolioCost();
        final pnl = value - cost;
        final pnlPct = cost == 0 ? 0.0 : pnl / cost * 100;

        final rows = app.holdings
            .map((h) => (h, h.amount * (tickers[h.symbol]?.price ?? h.avgBuy)))
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

        return PageBody(children: [
          _Summary(value: value, cost: cost, pnl: pnl, pnlPct: pnlPct, rows: rows),
          Panel(
            title: 'Holdings',
            subtitle: rows.isEmpty ? 'Nothing added yet' : '${rows.length} coins, sorted by value',
            explain: 'portfolio',
            trailing: AppButton(
              label: 'Add holding',
              icon: Icons.add_rounded,
              compact: true,
              onTap: () => showAddHolding(context),
            ),
            child: rows.isEmpty
                ? _Empty(onAdd: () => showAddHolding(context))
                : Column(children: [for (final r in rows) _HoldingRow(holding: r.$1, value: r.$2)]),
          ),
        ]);
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.value,
    required this.cost,
    required this.pnl,
    required this.pnlPct,
    required this.rows,
  });

  final double value, cost, pnl, pnlPct;
  final List<(Holding, double)> rows;

  @override
  Widget build(BuildContext context) {
    final up = pnl >= 0;
    final topShare = value == 0 || rows.isEmpty ? 0.0 : rows.first.$2 / value * 100;
    final insight = rows.isEmpty
        ? 'Add the coins you own and I will track their value and your profit or loss in real time.'
        : topShare > 50
            ? '${rows.first.$1.base} makes up ${topShare.round()}% of your portfolio. That is a lot in one coin: if it has a bad week, your whole portfolio feels it.'
            : 'Your biggest position, ${rows.first.$1.base}, is ${topShare.round()}% of the total. That is a reasonable spread.';

    final numbers = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total value', style: AppText.body(14, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(Fmt.usd(value), style: AppText.display(40)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: up ? AppColors.bull : AppColors.bear, size: 20),
            const SizedBox(width: 6),
            Text('${up ? '+' : '-'}${Fmt.usd(pnl.abs())}  (${Fmt.pct(pnlPct)})',
                style: AppText.number(15.5, color: up ? AppColors.bull : AppColors.bear)),
          ],
        ),
        const SizedBox(height: 4),
        Text('You put in ${Fmt.usd(cost)}', style: AppText.body(13.5, color: AppColors.faint)),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SageAvatar(size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(insight, style: AppText.body(14.5, height: 1.55))),
          ],
        ),
      ],
    );

    final ring = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonutChart(
          slices: [for (final r in rows) DonutSlice(r.$2, CoinAvatar.colorFor(r.$1.base))],
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${rows.length}', style: AppText.display(28)),
              Text(rows.length == 1 ? 'coin' : 'coins', style: AppText.body(13, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: CoinAvatar.colorFor(r.$1.base), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 44, child: Text(r.$1.base, style: AppText.body(13.5, w: FontWeight.w600))),
                    Text(value == 0 ? '0%' : '${(r.$2 / value * 100).round()}%',
                        style: AppText.number(13.5, color: AppColors.muted)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );

    return Panel(
      padding: const EdgeInsets.all(28),
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: numbers), const SizedBox(width: 32), ring],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            numbers,
            const SizedBox(height: 24),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: ring),
          ],
        );
      }),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding, required this.value});
  final Holding holding;
  final double value;

  @override
  Widget build(BuildContext context) {
    final market = context.market;
    final app = context.app;
    final price = market.tickers[holding.symbol]?.price ?? holding.avgBuy;
    final pnl = (price - holding.avgBuy) * holding.amount;
    final pnlPct = (price - holding.avgBuy) / holding.avgBuy * 100;
    final name = MockData.names[holding.symbol] ?? holding.base;

    final limitText = [
      if (holding.stopLossPct != null) 'Stop at -${holding.stopLossPct!.round()}%',
      if (holding.takeProfitPct != null) 'Target +${holding.takeProfitPct!.round()}%',
    ].join(', ');

    Future<void> remove() async {
      final ok = await confirmPop(
        context,
        title: 'Remove $name?',
        message: 'This removes ${holding.base} from your portfolio and its profit & loss limits. Your alerts stay as they are.',
        confirmLabel: 'Remove $name',
      );
      if (ok) {
        app.removeHolding(holding.symbol);
        if (context.mounted) toast(context, '$name removed from your portfolio');
      }
    }

    final title = Row(
      children: [
        CoinAvatar(holding.base, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.body(15, w: FontWeight.w600)),
              Text('${Fmt.coin(holding.amount)} ${holding.base} at ${Fmt.usd(holding.avgBuy)} average',
                  style: AppText.body(12.5, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );

    final figures = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(Fmt.usd(value), style: AppText.number(15.5)),
        Text('${pnl >= 0 ? '+' : '-'}${Fmt.usd(pnl.abs())} (${Fmt.pct(pnlPct)})',
            style: AppText.number(13, color: pnl >= 0 ? AppColors.bull : AppColors.bear)),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit profit & loss limits',
          onPressed: () => app.go(3),
          icon: const Icon(Icons.tune_rounded, size: 20),
        ),
        IconButton(
          tooltip: 'Remove',
          onPressed: remove,
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final limitTag = Tag(limitText.isEmpty ? 'No limits set' : limitText,
            color: limitText.isEmpty ? AppColors.warn : AppColors.muted);
        if (box.maxWidth >= 700) {
          return Row(
            children: [
              Expanded(flex: 3, child: title),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Now ${Fmt.usd(price)}', style: AppText.number(13.5, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    limitTag,
                  ],
                ),
              ),
              Expanded(flex: 2, child: figures),
              const SizedBox(width: 8),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Align(alignment: Alignment.centerLeft, child: limitTag)),
                figures,
              ],
            ),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        );
      }),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 40, color: AppColors.faint),
            const SizedBox(height: 12),
            Text('Add the coins you own to track their value in real time.',
                textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.muted)),
            const SizedBox(height: 16),
            AppButton(label: 'Add your first holding', icon: Icons.add_rounded, onTap: onAdd),
          ],
        ),
      );
}

// ---------------------------------------------------------------- add popup
Future<void> showAddHolding(BuildContext context) =>
    showPop<void>(context, child: const _AddHoldingForm());

class _AddHoldingForm extends StatefulWidget {
  const _AddHoldingForm();

  @override
  State<_AddHoldingForm> createState() => _AddHoldingFormState();
}

class _AddHoldingFormState extends State<_AddHoldingForm> {
  String _symbol = 'BTCUSDT';
  final _amount = TextEditingController();
  final _price = TextEditingController();
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_price.text.isEmpty) _setPrice();
  }

  void _setPrice() {
    final p = context.market.ticker(_symbol).price;
    _price.text = p >= 1 ? p.toStringAsFixed(2) : p.toStringAsFixed(4);
  }

  @override
  void dispose() {
    _amount.dispose();
    _price.dispose();
    super.dispose();
  }

  double? _num(String s) => double.tryParse(s.replaceAll(',', '').trim());

  void _save() {
    final amount = _num(_amount.text);
    final price = _num(_price.text);
    if (amount == null || amount <= 0 || price == null || price <= 0) {
      setState(() => _error = 'Enter an amount and a price greater than zero.');
      return;
    }
    context.app.addHolding(_symbol, amount, price);
    toast(context, 'Added ${Fmt.coin(amount)} ${_symbol.replaceAll('USDT', '')} to your portfolio');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final amount = _num(_amount.text) ?? 0;
    final price = _num(_price.text) ?? 0;
    return PopCard(
      title: 'Add a holding',
      subtitle: 'Record a coin you bought',
      icon: Icons.add_chart_rounded,
      actions: [
        AppButton(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          color: AppColors.muted,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Add holding', icon: Icons.check_rounded, onTap: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Coin'),
          CoinChoice(
            selected: _symbol,
            onChanged: (s) => setState(() {
              _symbol = s;
              _setPrice();
            }),
          ),
          const FieldLabel('How many coins'),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'For example 0.25'),
            style: AppText.number(15, w: FontWeight.w500),
            onChanged: (_) => setState(() => _error = null),
          ),
          const FieldLabel('Price you paid per coin (USD)'),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixText: '\$ '),
            style: AppText.number(15, w: FontWeight.w500),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!, style: AppText.body(13.5, color: AppColors.bear))
          else
            Text(
              amount > 0 && price > 0
                  ? 'Total cost: ${Fmt.usd(amount * price)}'
                  : 'The price is filled in with the current market price. Change it to what you actually paid.',
              style: AppText.body(13.5, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}
