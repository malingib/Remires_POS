import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the local SQLite database. Pass [path] (e.g. inMemoryDatabasePath)
/// in tests; the app uses the default location.
class AppDatabase {
  static const int schemaVersion = 1;

  static Future<Database> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'shop_stock.db');
    return openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        for (final statement in _schema) {
          await db.execute(statement);
        }
      },
      // v1 is the first release; keep this stub so bumping [schemaVersion]
      // later fails loudly instead of silently wiping user data.
      // Add `if (oldVersion < 2) { ... }` migrations here.
      onUpgrade: (db, oldVersion, newVersion) async {
        throw StateError(
          'No migration from v$oldVersion to v$newVersion. Add one in AppDatabase.onUpgrade.',
        );
      },
    );
  }

  static const List<String> _schema = [
    '''
    CREATE TABLE items(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      unit TEXT NOT NULL DEFAULT 'pcs',
      sell_price_minor INTEGER NOT NULL DEFAULT 0,
      reorder_level REAL NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      deleted_at TEXT
    )''',
    // The ledger. Stock on hand is never stored; it is derived from these rows.
    // qty_delta is signed: + stock in, - stock out.
    // occurred_on is the business date (YYYY-MM-DD) and may be backdated;
    // recorded_at is when the row was actually entered.
    '''
    CREATE TABLE stock_movements(
      id TEXT PRIMARY KEY,
      item_id TEXT NOT NULL REFERENCES items(id),
      type TEXT NOT NULL,
      qty_delta REAL NOT NULL,
      unit_cost_minor INTEGER,
      unit_price_minor INTEGER,
      occurred_on TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      note TEXT,
      batch_id TEXT,
      deleted_at TEXT
    )''',
    'CREATE INDEX idx_movements_item ON stock_movements(item_id, occurred_on)',
    'CREATE INDEX idx_movements_batch ON stock_movements(batch_id)',
    '''
    CREATE TABLE expenses(
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      occurred_on TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      note TEXT,
      batch_id TEXT,
      deleted_at TEXT
    )''',
    'CREATE INDEX idx_expenses_date ON expenses(occurred_on)',
    '''
    CREATE TABLE app_metadata(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )''',
  ];
}
