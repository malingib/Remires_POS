import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/errors.dart';
import '../core/format.dart';
import 'models.dart';

/// All reads and writes to SQLite. The UI never touches the database directly.
/// Every write works offline; a sync layer can be added on top later.
class ShopRepository {
  ShopRepository(this._db);

  final Database _db;
  static const Uuid _uuid = Uuid();

  // ---------------------------------------------------------------- items

  Future<List<Item>> items() async {
    final rows = await _db.query(
      'items',
      where: 'deleted_at IS NULL',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Item.fromMap).toList();
  }

  Future<Item> addItem({
    required String name,
    String unit = 'pcs',
    int sellPriceMinor = 0,
    double reorderLevel = 0,
  }) async {
    final clean = _validateItem(name, sellPriceMinor, reorderLevel);
    await _ensureUniqueName(clean);
    final now = DateTime.now().toUtc();
    final item = Item(
      id: _uuid.v4(),
      name: clean,
      unit: unit.trim().isEmpty ? 'pcs' : unit.trim(),
      sellPriceMinor: sellPriceMinor,
      reorderLevel: reorderLevel,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );
    await _db.insert('items', item.toMap());
    return item;
  }

  Future<void> updateItem(
    Item item, {
    required String name,
    required String unit,
    required int sellPriceMinor,
    required double reorderLevel,
  }) async {
    final clean = _validateItem(name, sellPriceMinor, reorderLevel);
    await _ensureUniqueName(clean, exceptId: item.id);
    final count = await _db.update(
      'items',
      {
        'name': clean,
        'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
        'sell_price_minor': sellPriceMinor,
        'reorder_level': reorderLevel,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'version': item.version + 1,
      },
      where: 'id = ? AND version = ?',
      whereArgs: [item.id, item.version],
    );
    if (count == 0) {
      throw const ValidationException(
        'This item was changed elsewhere. Reopen it and try again.',
      );
    }
  }

  String _validateItem(String name, int sellPriceMinor, double reorderLevel) {
    final clean = name.trim();
    if (clean.isEmpty) throw const ValidationException('Item name is required.');
    if (sellPriceMinor < 0) {
      throw const ValidationException('Price cannot be negative.');
    }
    if (reorderLevel < 0) {
      throw const ValidationException('Reorder level cannot be negative.');
    }
    return clean;
  }

  Future<void> _ensureUniqueName(String name, {String? exceptId}) async {
    final rows = await _db.query(
      'items',
      columns: ['id'],
      where: 'deleted_at IS NULL AND LOWER(name) = ?',
      whereArgs: [name.toLowerCase()],
    );
    final clash = rows.any((r) => r['id'] != exceptId);
    if (clash) throw ValidationException('"$name" already exists.');
  }

  // ------------------------------------------------------------- movements

  /// [quantity] is entered as a positive number for opening/purchase/sale
  /// (the sign is applied here). For adjustments it is signed: use a negative
  /// number for a loss.
  Future<StockMovement> addMovement({
    required String itemId,
    required MovementType type,
    required double quantity,
    int? unitCostMinor,
    int? unitPriceMinor,
    DateTime? occurredOn,
    String? note,
    String? batchId,
  }) async {
    if (quantity.isNaN || quantity.isInfinite || quantity == 0) {
      throw const ValidationException('Enter a quantity greater than zero.');
    }
    switch (type) {
      case MovementType.opening:
      case MovementType.purchase:
        if (quantity < 0) {
          throw const ValidationException('Quantity cannot be negative.');
        }
        if (unitCostMinor == null || unitCostMinor < 0) {
          throw const ValidationException('Enter the cost per unit.');
        }
      case MovementType.sale:
        if (quantity < 0) {
          throw const ValidationException('Quantity cannot be negative.');
        }
        if (unitPriceMinor == null || unitPriceMinor < 0) {
          throw const ValidationException('Enter the selling price.');
        }
      case MovementType.adjustment:
        // Positive adjustments (stock found) may carry a cost so average
        // cost can be established when balance was zero. Negative
        // adjustments are valued at the running average, cost is ignored.
        if (unitCostMinor != null && unitCostMinor < 0) {
          throw const ValidationException('Cost cannot be negative.');
        }
        break;
    }

    final day = dateOnly(occurredOn ?? DateTime.now());
    if (day.isAfter(dateOnly(DateTime.now()))) {
      throw const ValidationException('Date cannot be in the future.');
    }
    final itemRows = await _db.query(
      'items',
      columns: ['id'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [itemId],
    );
    if (itemRows.isEmpty) {
      throw const ValidationException('That item no longer exists.');
    }

    final movement = StockMovement(
      id: _uuid.v4(),
      itemId: itemId,
      type: type,
      qtyDelta: type == MovementType.sale ? -quantity : quantity,
      unitCostMinor: unitCostMinor,
      unitPriceMinor: unitPriceMinor,
      occurredOn: day,
      recordedAt: DateTime.now().toUtc(),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      batchId: batchId,
    );
    try {
      await _db.insert('stock_movements', movement.toMap());
    } on DatabaseException {
      throw const ValidationException('Could not save: item may be deleted.');
    }
    return movement;
  }

  /// Newest business date first.
  Future<List<StockMovement>> movements({String? itemId, int? limit}) async {
    final rows = await _db.query(
      'stock_movements',
      where: itemId == null
          ? 'deleted_at IS NULL'
          : 'deleted_at IS NULL AND item_id = ?',
      whereArgs: itemId == null ? null : [itemId],
      orderBy: 'occurred_on DESC, recorded_at DESC',
      limit: limit,
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  /// Returns true when a row was actually marked deleted.
  Future<bool> deleteMovement(String id) =>
      _softDelete('stock_movements', id);

  // -------------------------------------------------------------- expenses

  Future<Expense> addExpense({
    required String category,
    required int amountMinor,
    DateTime? occurredOn,
    String? note,
    String? batchId,
  }) async {
    if (category.trim().isEmpty) {
      throw const ValidationException('Choose a category.');
    }
    if (amountMinor <= 0) {
      throw const ValidationException('Enter an amount greater than zero.');
    }
    final day = dateOnly(occurredOn ?? DateTime.now());
    if (day.isAfter(dateOnly(DateTime.now()))) {
      throw const ValidationException('Date cannot be in the future.');
    }
    final expense = Expense(
      id: _uuid.v4(),
      category: category.trim(),
      amountMinor: amountMinor,
      occurredOn: day,
      recordedAt: DateTime.now().toUtc(),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      batchId: batchId,
    );
    await _db.insert('expenses', expense.toMap());
    return expense;
  }

  /// [from] inclusive, [to] exclusive.
  Future<List<Expense>> expenses({DateTime? from, DateTime? to, int? limit}) async {
    final where = <String>['deleted_at IS NULL'];
    final args = <Object>[];
    if (from != null) {
      where.add('occurred_on >= ?');
      args.add(ymd(from));
    }
    if (to != null) {
      where.add('occurred_on < ?');
      args.add(ymd(to));
    }
    final rows = await _db.query(
      'expenses',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'occurred_on DESC, recorded_at DESC',
      limit: limit,
    );
    return rows.map(Expense.fromMap).toList();
  }

  /// Returns true when a row was actually marked deleted.
  Future<bool> deleteExpense(String id) => _softDelete('expenses', id);

  // --------------------------------------------------------------- batches

  /// Removes everything created by one import in a single step.
  /// Returns how many rows were removed.
  Future<int> undoBatch(String batchId) async {
    if (batchId.trim().isEmpty) {
      throw const ValidationException('Batch id is required.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    return _db.transaction((txn) async {
      final a = await txn.update(
        'stock_movements',
        {'deleted_at': now},
        where: 'batch_id = ? AND deleted_at IS NULL',
        whereArgs: [batchId],
      );
      final b = await txn.update(
        'expenses',
        {'deleted_at': now},
        where: 'batch_id = ? AND deleted_at IS NULL',
        whereArgs: [batchId],
      );
      return a + b;
    });
  }

  Future<bool> _softDelete(String table, String id) async {
    final count = await _db.update(
      table,
      {'deleted_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    return count > 0;
  }
}
