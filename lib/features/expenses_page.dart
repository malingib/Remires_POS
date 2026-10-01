import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/format.dart';
import '../data/models.dart';
import 'shop_controller.dart';

const List<String> expenseCategories = [
  'Salary',
  'Rent',
  'Utilities',
  'Transport',
  'Other',
];

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ShopController>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const ExpenseDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
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
            child: c.recentExpenses.isEmpty
                ? Center(
                    child: Text(
                      c.loading
                          ? 'Loading…'
                          : 'No expenses yet. Add salary, rent and other costs.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: c.refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: c.recentExpenses.length +
                          (c.expensesHasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i >= c.recentExpenses.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: TextButton(
                                onPressed: c.loadMoreExpenses,
                                child: const Text('Show more'),
                              ),
                            ),
                          );
                        }
                        final e = c.recentExpenses[i];
                        return Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: const Icon(Icons.delete_outline),
                          ),
                          confirmDismiss: (_) async {
                            await _confirmDelete(context, e);
                            return false;
                          },
                          child: ListTile(
                            title: Text(e.category),
                            subtitle: Text(
                              '${Fmt.date(e.occurredOn)}${e.note == null ? '' : '  -  ${e.note}'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(Money.format(e.amountMinor)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete expense',
                                  onPressed: () =>
                                      _confirmDelete(context, e),
                                ),
                              ],
                            ),
                            onLongPress: () => _confirmDelete(context, e),
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

  Future<void> _confirmDelete(BuildContext context, Expense e) async {
    final c = context.read<ShopController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this expense?'),
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
    if (ok == true) await c.deleteExpense(e.id);
  }
}

class ExpenseDialog extends StatefulWidget {
  const ExpenseDialog({super.key});

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = expenseCategories.first;
  DateTime _date = dateOnly(DateTime.now());
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
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
    final parsed = Money.parse(_amount.text.trim());
    if (parsed == null) {
      setState(() => _error = 'Enter a valid amount, e.g. 1,250.50.');
      return;
    }
    try {
      await c.addExpense(
        category: _category,
        amountMinor: parsed,
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
    return AlertDialog(
      title: const Text('Add expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final cat in expenseCategories)
                  ChoiceChip(
                    label: Text(cat),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  ),
              ],
            ),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(Fmt.date(_date)),
              subtitle: const Text('Date'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
