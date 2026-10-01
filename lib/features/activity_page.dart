import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/format.dart';
import '../data/models.dart';
import 'shop_controller.dart';

/// The stock ledger: every sale, purchase, opening balance and adjustment.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ShopController>();
    final names = c.itemsById;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (c.items.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add an item first.')),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MovementForm()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Record'),
      ),
      body: Column(
        children: [
          if (c.loadError != null)
            MaterialBanner(
              content: Text(c.loadError!),
              actions: [
                TextButton(
                  onPressed: c.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: c.recentMovements.isEmpty
                ? Center(
                    child: Text(
                      c.loading
                          ? 'Loading…'
                          : 'No activity yet. Record a sale or purchase.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: c.refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: c.recentMovements.length +
                          (c.movementsHasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i >= c.recentMovements.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: TextButton(
                                onPressed: c.loadMoreMovements,
                                child: const Text('Show more'),
                              ),
                            ),
                          );
                        }
                        final m = c.recentMovements[i];
                        final item = names[m.itemId];
                        final unit = item?.unit ?? '';
                        final amount = m.type == MovementType.sale
                            ? m.unitPriceMinor
                            : m.unitCostMinor;
                        final sign = m.qtyDelta > 0 ? '+' : '';
                        return Dismissible(
                          key: ValueKey(m.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: const Icon(Icons.delete_outline),
                          ),
                          confirmDismiss: (_) async {
                            await _confirmDelete(context, m);
                            return false;
                          },
                          child: ListTile(
                            title: Text(item?.name ?? 'Unknown item'),
                            subtitle: Text(
                              '${m.type.label}  -  ${Fmt.date(m.occurredOn)}'
                              '${m.note == null ? '' : '\n${m.note}'}',
                            ),
                            isThreeLine: m.note != null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('$sign${Fmt.qty(m.qtyDelta)} $unit'),
                                    if (amount != null)
                                      Text('@ ${Money.format(amount)}'),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete entry',
                                  onPressed: () =>
                                      _confirmDelete(context, m),
                                ),
                              ],
                            ),
                            onLongPress: () => _confirmDelete(context, m),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, StockMovement m) async {
    final c = context.read<ShopController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('Stock and profit figures will be recalculated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await c.deleteMovement(m.id);
  }
}

class MovementForm extends StatefulWidget {
  const MovementForm({super.key});

  @override
  State<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<MovementForm> {
  final _qty = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  MovementType _type = MovementType.sale;
  Item? _item;
  DateTime _date = dateOnly(DateTime.now());
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _needsCost =>
      _type == MovementType.purchase || _type == MovementType.opening;
  bool get _needsPrice => _type == MovementType.sale;
  bool get _isAdjustment => _type == MovementType.adjustment;

  void _prefillPrice() {
    if (_needsPrice && _item != null && _amount.text.trim().isEmpty) {
      _amount.text = (_item!.sellPriceMinor / 100).toStringAsFixed(2);
    }
  }

  Future<void> _pickItem() async {
    final items = context.read<ShopController>().items;
    final picked = await showDialog<Item>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose item'),
        children: [
          for (final i in items)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(i),
              child: Text(i.name),
            ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _item = picked;
        _prefillPrice();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final c = context.read<ShopController>();
    final item = _item;
    if (item == null) {
      setState(() => _error = 'Choose an item.');
      return;
    }
    final qty = double.tryParse(_qty.text.trim());
    if (qty == null) {
      setState(() => _error = 'Enter a valid quantity.');
      return;
    }
    final amountText = _amount.text.trim();
    final int? money;
    if (_needsCost || _needsPrice || _isAdjustment) {
      if (amountText.isEmpty) {
        money = null;
      } else {
        money = Money.parse(amountText);
        if (money == null) {
          setState(() => _error = 'Enter a valid amount.');
          return;
        }
      }
    } else {
      money = null;
    }
    try {
      await c.addMovement(
        itemId: item.id,
        type: _type,
        quantity: qty,
        unitCostMinor: (_needsCost || _isAdjustment) ? money : null,
        unitPriceMinor: _needsPrice ? money : null,
        occurredOn: _date,
        note: _note.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on ValidationException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _date == dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Record activity')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<MovementType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: MovementType.sale, label: Text('Sale')),
              ButtonSegment(value: MovementType.purchase, label: Text('Purchase')),
              ButtonSegment(value: MovementType.adjustment, label: Text('Adjust')),
              ButtonSegment(value: MovementType.opening, label: Text('Opening')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _amount.clear();
              _prefillPrice();
            }),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_item?.name ?? 'Choose item'),
            subtitle: const Text('Item'),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: _pickItem,
          ),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: 'Quantity${_item == null ? '' : ' (${_item!.unit})'}',
              helperText: _type == MovementType.adjustment
                  ? 'Use a minus sign for stock lost or damaged, e.g. -2'
                  : null,
            ),
          ),
          if (_needsCost || _needsPrice)
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _needsPrice ? 'Selling price per unit' : 'Cost per unit',
              ),
            ),
          if (_isAdjustment)
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cost per unit (optional)',
                helperText:
                    'Fill when adding found stock so future sales are valued correctly.',
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(isToday ? 'Today' : Fmt.date(_date)),
            subtitle: const Text('Date (you can backdate)'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
