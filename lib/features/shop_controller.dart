import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../domain/report_service.dart';

/// Holds what the screens show. Every action writes to SQLite first and then
/// reloads, so the UI never depends on the network.
class ShopController extends ChangeNotifier {
  ShopController(this.repo) : _reports = ReportService(repo);

  final ShopRepository repo;
  final ReportService _reports;

  List<Item> items = const [];
  List<StockMovement> recentMovements = const [];
  List<Expense> recentExpenses = const [];
  ShopReport? report;
  bool loading = false;
  String? loadError;

  static const int pageSize = 200;
  int _movementLimit = pageSize;
  int _expenseLimit = pageSize;
  bool movementsHasMore = false;
  bool expensesHasMore = false;

  Map<String, Item> get itemsById => {for (final i in items) i.id: i};

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final tomorrow = dateOnly(now).add(const Duration(days: 1));
      final results = await Future.wait([
        repo.items(),
        repo.movements(limit: _movementLimit + 1),
        repo.expenses(limit: _expenseLimit + 1),
      ]);
      items = results[0] as List<Item>;
      final allMovements = results[1] as List<StockMovement>;
      final allExpenses = results[2] as List<Expense>;
      movementsHasMore = allMovements.length > _movementLimit;
      expensesHasMore = allExpenses.length > _expenseLimit;
      recentMovements = movementsHasMore
          ? allMovements.sublist(0, _movementLimit)
          : allMovements;
      recentExpenses = expensesHasMore
          ? allExpenses.sublist(0, _expenseLimit)
          : allExpenses;
      // Full ledger replay keeps average cost correct even when the period
      // starts mid-history. O(n) in ledger size; for very large histories
      // move to incremental balances or an isolate (see ReportService).
      report = await _reports.build(from: monthStart, to: tomorrow);
      loadError = null;
    } catch (e, st) {
      debugPrint('ShopController.refresh failed: $e\n$st');
      loadError = 'Could not load your data. Pull down to try again.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMoreMovements() async {
    if (!movementsHasMore || loading) return;
    _movementLimit += pageSize;
    await refresh();
  }

  Future<void> loadMoreExpenses() async {
    if (!expensesHasMore || loading) return;
    _expenseLimit += pageSize;
    await refresh();
  }

  Future<void> addItem({
    required String name,
    required String unit,
    required int sellPriceMinor,
    required double reorderLevel,
  }) async {
    await repo.addItem(
      name: name,
      unit: unit,
      sellPriceMinor: sellPriceMinor,
      reorderLevel: reorderLevel,
    );
    await refresh();
  }

  Future<void> updateItem(
    Item item, {
    required String name,
    required String unit,
    required int sellPriceMinor,
    required double reorderLevel,
  }) async {
    await repo.updateItem(
      item,
      name: name,
      unit: unit,
      sellPriceMinor: sellPriceMinor,
      reorderLevel: reorderLevel,
    );
    await refresh();
  }

  Future<void> addMovement({
    required String itemId,
    required MovementType type,
    required double quantity,
    int? unitCostMinor,
    int? unitPriceMinor,
    DateTime? occurredOn,
    String? note,
  }) async {
    await repo.addMovement(
      itemId: itemId,
      type: type,
      quantity: quantity,
      unitCostMinor: unitCostMinor,
      unitPriceMinor: unitPriceMinor,
      occurredOn: occurredOn ?? dateOnly(DateTime.now()),
      note: note,
    );
    await refresh();
  }

  Future<void> deleteMovement(String id) async {
    await repo.deleteMovement(id);
    await refresh();
  }

  Future<void> addExpense({
    required String category,
    required int amountMinor,
    DateTime? occurredOn,
    String? note,
  }) async {
    await repo.addExpense(
      category: category,
      amountMinor: amountMinor,
      occurredOn: occurredOn,
      note: note,
    );
    await refresh();
  }

  Future<void> deleteExpense(String id) async {
    await repo.deleteExpense(id);
    await refresh();
  }
}
