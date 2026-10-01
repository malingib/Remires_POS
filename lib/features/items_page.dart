import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/format.dart';
import '../data/models.dart';
import 'shop_controller.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ShopController>();
    final q = _query.trim().toLowerCase();
    final shown = c.items.where((i) => q.isEmpty || i.name.toLowerCase().contains(q)).toList();
    final stock = c.report?.stock ?? const {};

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const ItemDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search items',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(c.loading
                        ? 'Loading…'
                        : c.items.isEmpty
                            ? 'No items yet. Tap "Add item" to start.'
                            : 'No items match your search.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = shown[i];
                      final s = stock[item.id];
                      final qty = s?.qty ?? 0;
                      final low = item.reorderLevel > 0 && qty <= item.reorderLevel;
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${Fmt.qty(qty)} ${item.unit} in stock'
                          '${low ? '  -  low stock' : ''}',
                          style: low
                              ? TextStyle(color: Theme.of(context).colorScheme.error)
                              : null,
                        ),
                        trailing: Text(Money.format(item.sellPriceMinor)),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => ItemDialog(item: item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ItemDialog extends StatefulWidget {
  const ItemDialog({super.key, this.item});

  final Item? item;

  @override
  State<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<ItemDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.item?.name ?? '');
  late final TextEditingController _unit =
      TextEditingController(text: widget.item?.unit ?? 'pcs');
  late final TextEditingController _price = TextEditingController(
    text: widget.item == null
        ? ''
        : (widget.item!.sellPriceMinor / 100).toStringAsFixed(2),
  );
  late final TextEditingController _reorder = TextEditingController(
    text: widget.item == null || widget.item!.reorderLevel == 0
        ? ''
        : Fmt.qty(widget.item!.reorderLevel),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _price.dispose();
    _reorder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = context.read<ShopController>();
    try {
      final priceText = _price.text.trim();
      final int price;
      if (priceText.isEmpty) {
        price = 0;
      } else {
        final parsed = Money.parse(priceText);
        if (parsed == null) {
          throw const ValidationException('Enter a valid selling price.');
        }
        price = parsed;
      }
      final reorderText = _reorder.text.trim();
      final double reorder;
      if (reorderText.isEmpty) {
        reorder = 0;
      } else {
        final parsed = double.tryParse(reorderText);
        if (parsed == null || parsed.isNaN || parsed.isInfinite) {
          throw const ValidationException('Enter a valid reorder level.');
        }
        reorder = parsed;
      }
      if (widget.item == null) {
        await c.addItem(
          name: _name.text,
          unit: _unit.text,
          sellPriceMinor: price,
          reorderLevel: reorder,
        );
      } else {
        await c.updateItem(
          widget.item!,
          name: _name.text,
          unit: _unit.text,
          sellPriceMinor: price,
          reorderLevel: reorder,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ValidationException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add item' : 'Edit item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _unit,
              decoration: const InputDecoration(labelText: 'Unit (pcs, kg, box)'),
            ),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Selling price'),
            ),
            TextField(
              controller: _reorder,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Low stock alert at (optional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
