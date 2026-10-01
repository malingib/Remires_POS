import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../domain/report_service.dart';
import 'shop_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ShopController>();
    final r = c.report;

    if (r == null) {
      return Center(
        child: c.loadError != null
            ? Text(c.loadError!)
            : const CircularProgressIndicator(),
      );
    }

    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final month = Fmt.date(DateTime(now.year, now.month, 1));

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('This month (since $month)', style: text.titleMedium),
          const SizedBox(height: 8),
          _Line('Sales', r.revenueMinor),
          _Line('Cost of goods sold', -r.cogsMinor),
          _Line('Gross profit', r.grossProfitMinor, bold: true),
          _Line('Expenses (incl. salary)', -r.expensesMinor),
          if (r.shrinkageMinor > 0) _Line('Stock written off', -r.shrinkageMinor),
          const Divider(),
          _Line('Net profit', r.netProfitMinor, bold: true),
          const SizedBox(height: 24),
          Text('Stock', style: text.titleMedium),
          const SizedBox(height: 8),
          _Line('Value of stock on hand', r.stockValueMinor),
          if (r.negativeStockCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${r.negativeStockCount} item(s) show negative stock. A purchase '
                'or opening balance is probably missing.',
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Low stock', style: text.titleMedium),
          const SizedBox(height: 8),
          if (r.lowStock.isEmpty)
            Text(
              c.items.isEmpty
                  ? 'Add items and set a reorder level to get alerts.'
                  : 'Nothing is running low.',
              style: text.bodyMedium,
            )
          else
            ...r.lowStock.map(_lowStockTile),
        ],
      ),
    );
  }

  Widget _lowStockTile(LowStockItem l) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(l.item.name),
      trailing: Text('${Fmt.qty(l.qty)} ${l.item.unit} left'),
      subtitle: Text('Reorder at ${Fmt.qty(l.item.reorderLevel)}'),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.minor, {this.bold = false});

  final String label;
  final int minor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(Money.format(minor), style: style),
        ],
      ),
    );
  }
}
