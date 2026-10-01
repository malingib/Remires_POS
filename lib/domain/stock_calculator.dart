import '../data/models.dart';

/// Value of one movement after replaying the ledger.
class MovementValuation {
  const MovementValuation({
    this.cogsMinor = 0,
    this.revenueMinor = 0,
    this.lossMinor = 0,
    this.negativeStock = false,
  });

  /// Cost of goods sold (sales only).
  final int cogsMinor;

  /// Sales revenue (sales only).
  final int revenueMinor;

  /// Value of stock written off (negative adjustments only).
  final int lossMinor;

  /// True when stock on hand was below zero after this movement. Usually means
  /// a purchase or opening balance has not been recorded yet.
  final bool negativeStock;
}

class ItemStock {
  const ItemStock({
    required this.itemId,
    required this.qty,
    required this.avgCostMinor,
  });

  final String itemId;
  final double qty;
  final int avgCostMinor;

  int get valueMinor => qty > 0 ? (qty * avgCostMinor).round() : 0;
}

class StockResult {
  const StockResult({required this.stock, required this.valuations});

  final Map<String, ItemStock> stock;
  final Map<String, MovementValuation> valuations;
}

/// Replays the ledger per item, in business-date order, using weighted
/// average cost. Because it always replays from scratch, backdated entries
/// and imports simply "slot in" and every figure after them is corrected.
class StockCalculator {
  const StockCalculator();

  /// Tolerance for float comparisons. Quantities support up to 3 decimals
  /// (see Fmt.qty), so anything below half a thousandth is treated as zero.
  static const double _eps = 0.0005;

  StockResult calculate(Iterable<StockMovement> movements) {
    final byItem = <String, List<StockMovement>>{};
    for (final m in movements) {
      if (m.deletedAt != null) continue;
      byItem.putIfAbsent(m.itemId, () => []).add(m);
    }

    final stock = <String, ItemStock>{};
    final valuations = <String, MovementValuation>{};

    byItem.forEach((itemId, list) {
      list.sort(_compare);
      var qty = 0.0;
      var avg = 0.0;

      for (final m in list) {
        var cogs = 0;
        var revenue = 0;
        var loss = 0;

        switch (m.type) {
          case MovementType.opening:
          case MovementType.purchase:
            final cost = (m.unitCostMinor ?? 0).toDouble();
            final newQty = qty + m.qtyDelta;
            avg = (qty <= _eps || newQty <= _eps)
                ? cost
                : (qty * avg + m.qtyDelta * cost) / newQty;
            qty = newQty;
          case MovementType.sale:
            final units = -m.qtyDelta;
            cogs = (units * avg).round();
            revenue = (units * (m.unitPriceMinor ?? 0)).round();
            qty -= units;
          case MovementType.adjustment:
            if (m.qtyDelta < 0) {
              loss = (-m.qtyDelta * avg).round();
              qty += m.qtyDelta;
            } else {
              // Stock found / counted in. Keep the running average when we
              // already have stock; when balance is zero (or was negative)
              // adopt the provided cost so future sales are not valued at 0.
              final cost = m.unitCostMinor?.toDouble();
              if (qty <= _eps && cost != null && cost >= 0) {
                avg = cost;
              }
              qty += m.qtyDelta;
            }
        }

        valuations[m.id] = MovementValuation(
          cogsMinor: cogs,
          revenueMinor: revenue,
          lossMinor: loss,
          negativeStock: qty < -_eps,
        );
      }

      stock[itemId] = ItemStock(
        itemId: itemId,
        qty: qty,
        avgCostMinor: avg.round(),
      );
    });

    return StockResult(stock: stock, valuations: valuations);
  }

  static int _compare(StockMovement a, StockMovement b) {
    final byDate = a.occurredOn.compareTo(b.occurredOn);
    if (byDate != 0) return byDate;
    final byType = a.type.dayPriority.compareTo(b.type.dayPriority);
    if (byType != 0) return byType;
    return a.recordedAt.compareTo(b.recordedAt);
  }
}
