// db_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:runrank/calculator_logic.dart'; // <-- required for parsing time

class RunRankDB {
  static final RunRankDB instance = RunRankDB._init();
  static Database? _database;

  RunRankDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('runrank.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // 🔥 bump version so onUpgrade runs
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // -----------------------------
  // CREATE DATABASE (version 1)
  // -----------------------------
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race TEXT,
        gender TEXT,
        age INTEGER,
        distance TEXT,
        time TEXT,
        level TEXT,
        ageGrade REAL,
        createdAt TEXT,
        finishSeconds INTEGER
      )
    ''');
  }

  // -----------------------------
  // UPGRADE DATABASE (from v1 → v2)
  // -----------------------------
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new column
      await db.execute(
        'ALTER TABLE results ADD COLUMN finishSeconds INTEGER DEFAULT 0;',
      );

      // Backfill old rows using their stored time string
      final rows = await db.query('results');
      for (final row in rows) {
        final id = row['id'] as int;
        final timeString = row['time'] as String?;
        final secs = RunCalculator.parseTimeToSeconds(timeString ?? '') ?? 0;

        await db.update(
          'results',
          {'finishSeconds': secs},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  // -----------------------------
  // INSERT
  // -----------------------------
  Future<int> insertResult(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert('results', data);
  }

  // -----------------------------
  // READ
  // -----------------------------
  Future<List<Map<String, dynamic>>> getResults() async {
    final db = await instance.database;
    final results = await db.query('results', orderBy: 'createdAt DESC');
    print("=== FETCH RESULTS ===");
    print(results);
    return results;
  }

  // -----------------------------
  // CLEAR TABLE
  // -----------------------------
  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('results');
  }
}
