import '../data/models.dart';
import '../data/repository.dart';
import 'stock_calculator.dart';

class LowStockItem {
  const LowStockItem(this.item, this.qty);
  final Item item;
  final double qty;
}

class ShopReport {
  const ShopReport({
    required this.revenueMinor,
    required this.cogsMinor,
    required this.shrinkageMinor,
    required this.expensesMinor,
    required this.stockValueMinor,
    required this.lowStock,
    required this.negativeStockCount,
    required this.stock,
  });

  final int revenueMinor;
  final int cogsMinor;

  /// Value of stock written off through negative adjustments.
  final int shrinkageMinor;
  final int expensesMinor;

  /// Value of all stock currently on hand, at average cost.
  final int stockValueMinor;
  final List<LowStockItem> lowStock;

  /// Distinct items whose running balance dropped below zero at any point
  /// while replaying the ledger (usually a missing purchase record).
  /// This stays flagged even if a later purchase brings the balance back up.
  final int negativeStockCount;
  final Map<String, ItemStock> stock;

  int get grossProfitMinor => revenueMinor - cogsMinor;
  int get netProfitMinor => grossProfitMinor - shrinkageMinor - expensesMinor;
}

class ReportService {
  ReportService(this._repo, [StockCalculator? calculator])
      : _calc = calculator ?? const StockCalculator();

  final ShopRepository _repo;
  final StockCalculator _calc;

  /// Profit figures cover business dates in [from, to). Stock figures are
  /// always "as of now". The whole ledger is replayed so average cost stays
  /// correct even when the period starts mid-history.
  /// Scaling note: this is O(n) in ledger size and runs on the UI isolate
  /// via ShopController.refresh. For 10k+ movements, move to incremental
  /// balances (store running qty/avg per item) or compute in an isolate.
  Future<ShopReport> build({required DateTime from, required DateTime to}) async {
    final items = await _repo.items();
    final movements = await _repo.movements();
    final expenses = await _repo.expenses(from: from, to: to);
    final result = _calc.calculate(movements);

    var revenue = 0;
    var cogs = 0;
    var shrinkage = 0;
    for (final m in movements) {
      final inRange = !m.occurredOn.isBefore(from) && m.occurredOn.isBefore(to);
      if (!inRange) continue;
      final v = result.valuations[m.id];
      if (v == null) continue;
      revenue += v.revenueMinor;
      cogs += v.cogsMinor;
      shrinkage += v.lossMinor;
    }

    var stockValue = 0;
    final low = <LowStockItem>[];
    final everNegativeIds = <String>{};
    for (final m in movements) {
      if (result.valuations[m.id]?.negativeStock == true) {
        everNegativeIds.add(m.itemId);
      }
    }
    for (final item in items) {
      final s = result.stock[item.id];
      final qty = s?.qty ?? 0;
      stockValue += s?.valueMinor ?? 0;
      if (item.reorderLevel > 0 && qty <= item.reorderLevel) {
        low.add(LowStockItem(item, qty));
      }
    }
    final negative = everNegativeIds.length;
    low.sort((a, b) => a.qty.compareTo(b.qty));

    return ShopReport(
      revenueMinor: revenue,
      cogsMinor: cogs,
      shrinkageMinor: shrinkage,
      expensesMinor: expenses.fold<int>(0, (sum, e) => sum + e.amountMinor),
      stockValueMinor: stockValue,
      lowStock: low,
      negativeStockCount: negative,
      stock: result.stock,
    );
  }
}
