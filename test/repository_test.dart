import 'package:flutter_test/flutter_test.dart';
import 'package:shop_stock/core/errors.dart';
import 'package:shop_stock/core/format.dart';
import 'package:shop_stock/data/database.dart';
import 'package:shop_stock/data/models.dart';
import 'package:shop_stock/data/repository.dart';
import 'package:shop_stock/domain/report_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ShopRepository repo;
  late Database db;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = ShopRepository(db);
  });

  tearDown(() async {
    await db.close();
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
  });

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  test('sales, purchases and expenses produce the right profit', () async {
    final item = await repo.addItem(name: 'A4 Paper', unit: 'ream');
    await repo.addMovement(
      itemId: item.id,
      type: MovementType.purchase,
      quantity: 10,
      unitCostMinor: 10000,
    );
    await repo.addMovement(
      itemId: item.id,
      type: MovementType.sale,
      quantity: 4,
      unitPriceMinor: 15000,
    );
    await repo.addExpense(category: 'Salary', amountMinor: 5000);

    final report =
        await ReportService(repo).build(from: monthStart, to: tomorrow);

    expect(report.revenueMinor, 60000);
    expect(report.cogsMinor, 40000);
    expect(report.grossProfitMinor, 20000);
    expect(report.expensesMinor, 5000);
    expect(report.netProfitMinor, 15000);
    expect(report.stock[item.id]!.qty, 6);
  });

  test('low stock appears once quantity reaches the reorder level', () async {
    final item = await repo.addItem(name: 'Toner', reorderLevel: 3);
    await repo.addMovement(
      itemId: item.id,
      type: MovementType.opening,
      quantity: 5,
      unitCostMinor: 650000,
    );
    var report = await ReportService(repo).build(from: monthStart, to: tomorrow);
    expect(report.lowStock, isEmpty);

    await repo.addMovement(
      itemId: item.id,
      type: MovementType.sale,
      quantity: 2,
      unitPriceMinor: 800000,
    );
    report = await ReportService(repo).build(from: monthStart, to: tomorrow);
    expect(report.lowStock.single.item.name, 'Toner');
  });

  test('backdated entries land in the right period', () async {
    final item = await repo.addItem(name: 'Pens');
    final lastYear = DateTime(now.year - 1, 6, 15);
    await repo.addMovement(
      itemId: item.id,
      type: MovementType.opening,
      quantity: 10,
      unitCostMinor: 1000,
      occurredOn: lastYear,
    );
    await repo.addMovement(
      itemId: item.id,
      type: MovementType.sale,
      quantity: 2,
      unitPriceMinor: 2000,
      occurredOn: lastYear,
    );

    final thisMonth =
        await ReportService(repo).build(from: monthStart, to: tomorrow);
    expect(thisMonth.revenueMinor, 0);
    expect(thisMonth.stock[item.id]!.qty, 8);

    final thatDay = await ReportService(repo).build(
      from: lastYear,
      to: DateTime(lastYear.year, lastYear.month, lastYear.day + 1),
    );
    expect(thatDay.revenueMinor, 4000);
    expect(thatDay.cogsMinor, 2000);
  });

  test('undoing an import batch removes only that batch', () async {
    final item = await repo.addItem(name: 'Sugar');
    await repo.addMovement(
      itemId: item.id,
      type: MovementType.opening,
      quantity: 5,
      unitCostMinor: 1000,
    );
    await repo.addMovement(
      itemId: item.id,
      type: MovementType.purchase,
      quantity: 7,
      unitCostMinor: 1000,
      batchId: 'import-1',
    );

    final removed = await repo.undoBatch('import-1');
    expect(removed, 1);
    expect((await repo.movements()).length, 1);
  });

  test('bad input is rejected with a readable message', () async {
    final item = await repo.addItem(name: 'Rice');
    expect(
      () => repo.addMovement(
        itemId: item.id,
        type: MovementType.sale,
        quantity: 1,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(() => repo.addItem(name: 'rice'), throwsA(isA<ValidationException>()));
  });

  test('money parsing and formatting', () {
    expect(Money.parse('1,250.50'), 125050);
    expect(Money.parse('abc'), isNull);
    expect(Money.format(125050), 'KES 1,250.50');
  });
}
