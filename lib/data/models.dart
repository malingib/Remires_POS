import '../core/format.dart';

enum MovementType {
  opening,
  purchase,
  sale,
  adjustment;

  String get label => switch (this) {
        MovementType.opening => 'Opening stock',
        MovementType.purchase => 'Purchase',
        MovementType.sale => 'Sale',
        MovementType.adjustment => 'Adjustment',
      };

  /// Processing order inside a single day: stock arrives before it is sold.
  int get dayPriority => switch (this) {
        MovementType.opening => 0,
        MovementType.purchase => 1,
        MovementType.adjustment => 2,
        MovementType.sale => 3,
      };

  static MovementType parse(String value) =>
      MovementType.values.firstWhere((t) => t.name == value);
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.unit,
    required this.sellPriceMinor,
    required this.reorderLevel,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final String name;
  final String unit;
  final int sellPriceMinor;
  final double reorderLevel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'unit': unit,
        'sell_price_minor': sellPriceMinor,
        'reorder_level': reorderLevel,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'version': version,
      };

  factory Item.fromMap(Map<String, Object?> m) => Item(
        id: m['id'] as String,
        name: m['name'] as String,
        unit: m['unit'] as String,
        sellPriceMinor: m['sell_price_minor'] as int,
        reorderLevel: (m['reorder_level'] as num).toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        version: m['version'] as int,
      );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.type,
    required this.qtyDelta,
    required this.occurredOn,
    required this.recordedAt,
    this.unitCostMinor,
    this.unitPriceMinor,
    this.note,
    this.batchId,
    this.deletedAt,
  });

  final String id;
  final String itemId;
  final MovementType type;

  /// Signed: positive = stock in, negative = stock out.
  final double qtyDelta;
  final int? unitCostMinor;
  final int? unitPriceMinor;

  /// Business date (date only, may be backdated).
  final DateTime occurredOn;
  final DateTime recordedAt;
  final String? note;
  final String? batchId;
  final DateTime? deletedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'item_id': itemId,
        'type': type.name,
        'qty_delta': qtyDelta,
        'unit_cost_minor': unitCostMinor,
        'unit_price_minor': unitPriceMinor,
        'occurred_on': ymd(occurredOn),
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'note': note,
        'batch_id': batchId,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  factory StockMovement.fromMap(Map<String, Object?> m) => StockMovement(
        id: m['id'] as String,
        itemId: m['item_id'] as String,
        type: MovementType.parse(m['type'] as String),
        qtyDelta: (m['qty_delta'] as num).toDouble(),
        unitCostMinor: m['unit_cost_minor'] as int?,
        unitPriceMinor: m['unit_price_minor'] as int?,
        occurredOn: DateTime.parse(m['occurred_on'] as String),
        recordedAt: DateTime.parse(m['recorded_at'] as String),
        note: m['note'] as String?,
        batchId: m['batch_id'] as String?,
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amountMinor,
    required this.occurredOn,
    required this.recordedAt,
    this.note,
    this.batchId,
    this.deletedAt,
  });

  final String id;
  final String category;
  final int amountMinor;
  final DateTime occurredOn;
  final DateTime recordedAt;
  final String? note;
  final String? batchId;
  final DateTime? deletedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'category': category,
        'amount_minor': amountMinor,
        'occurred_on': ymd(occurredOn),
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'note': note,
        'batch_id': batchId,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as String,
        category: m['category'] as String,
        amountMinor: m['amount_minor'] as int,
        occurredOn: DateTime.parse(m['occurred_on'] as String),
        recordedAt: DateTime.parse(m['recorded_at'] as String),
        note: m['note'] as String?,
        batchId: m['batch_id'] as String?,
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
      );
}
