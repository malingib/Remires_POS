import 'package:flutter_test/flutter_test.dart';
import 'package:shop_stock/data/models.dart';
import 'package:shop_stock/domain/stock_calculator.dart';

// Money below is in minor units: 10000 = 100.00.
StockMovement mv(
  String id,
  MovementType type,
  double delta,
  String on, {
  int? cost,
  int? price,
  String recorded = '2026-10-01T08:00:00Z',
}) =>
    StockMovement(
      id: id,
      itemId: 'i1',
      type: type,
      qtyDelta: delta,
      unitCostMinor: cost,
      unitPriceMinor: price,
      occurredOn: DateTime.parse(on),
      recordedAt: DateTime.parse(recorded),
    );

void main() {
  const calc = StockCalculator();

  test('weighted average cost across two purchases', () {
    final r = calc.calculate([
      mv('a', MovementType.purchase, 10, '2026-09-01', cost: 10000),
      mv('b', MovementType.purchase, 10, '2026-09-02', cost: 20000),
      mv('c', MovementType.sale, -5, '2026-09-03', price: 30000),
    ]);

    expect(r.stock['i1']!.qty, 15);
    expect(r.stock['i1']!.avgCostMinor, 15000);
    expect(r.valuations['c']!.cogsMinor, 75000); // 5 x 150.00
    expect(r.valuations['c']!.revenueMinor, 150000); // 5 x 300.00
    expect(r.stock['i1']!.valueMinor, 225000); // 15 x 150.00
  });

  test('backdated purchase entered later still costs the earlier sale', () {
    final r = calc.calculate([
      // Sale on 10 Sep was typed in first...
      mv('sale', MovementType.sale, -3, '2026-09-10',
          price: 20000, recorded: '2026-10-01T10:00:00Z'),
      // ...the purchase it depends on was entered later, dated 5 Sep.
      mv('buy', MovementType.purchase, 10, '2026-09-05',
          cost: 10000, recorded: '2026-10-01T11:00:00Z'),
    ]);

    expect(r.valuations['sale']!.cogsMinor, 30000);
    expect(r.valuations['sale']!.negativeStock, isFalse);
    expect(r.stock['i1']!.qty, 7);
  });

  test('same-day purchase is processed before the sale', () {
    final r = calc.calculate([
      mv('sale', MovementType.sale, -2, '2026-09-10',
          price: 20000, recorded: '2026-10-01T09:00:00Z'),
      mv('buy', MovementType.purchase, 5, '2026-09-10',
          cost: 10000, recorded: '2026-10-01T09:30:00Z'),
    ]);

    expect(r.valuations['sale']!.negativeStock, isFalse);
    expect(r.valuations['sale']!.cogsMinor, 20000);
  });

  test('selling more than recorded stock is flagged, not blocked', () {
    final r = calc.calculate([
      mv('buy', MovementType.purchase, 2, '2026-09-01', cost: 10000),
      mv('sale', MovementType.sale, -5, '2026-09-02', price: 20000),
    ]);

    expect(r.valuations['sale']!.negativeStock, isTrue);
    expect(r.stock['i1']!.qty, -3);
    expect(r.stock['i1']!.valueMinor, 0);
  });

  test('negative adjustment is valued at average cost as a loss', () {
    final r = calc.calculate([
      mv('buy', MovementType.opening, 10, '2026-09-01', cost: 10000),
      mv('adj', MovementType.adjustment, -2, '2026-09-05'),
    ]);

    expect(r.valuations['adj']!.lossMinor, 20000);
    expect(r.stock['i1']!.qty, 8);
    expect(r.stock['i1']!.avgCostMinor, 10000);
  });

  test('deleted movements are ignored', () {
    final deleted = StockMovement(
      id: 'x',
      itemId: 'i1',
      type: MovementType.purchase,
      qtyDelta: 100,
      unitCostMinor: 10000,
      occurredOn: DateTime.parse('2026-09-01'),
      recordedAt: DateTime.parse('2026-10-01T08:00:00Z'),
      deletedAt: DateTime.parse('2026-10-01T09:00:00Z'),
    );
    final r = calc.calculate([deleted]);
    expect(r.stock.containsKey('i1'), isFalse);
  });
}
