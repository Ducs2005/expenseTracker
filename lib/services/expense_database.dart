import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/category_budget.dart';
import '../models/expense.dart';

class ExpenseDatabase {
  ExpenseDatabase._();

  static final instance = ExpenseDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final databasesPath = await getDatabasesPath();
    // Keep the earlier USD ledger intact; VND records use a separate database.
    final filePath = path.join(databasesPath, 'receiptwise_vnd.db');
    _database = await openDatabase(
      filePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            category TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            category TEXT NOT NULL,
            month TEXT NOT NULL,
            amount REAL NOT NULL,
            PRIMARY KEY (category, month)
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Expense>> getAll() async {
    final rows = await (await database).query('expenses', orderBy: 'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<void> insert(Expense expense) async {
    await (await database).insert('expenses', expense.toMap());
  }

  Future<void> delete(int id) async {
    await (await database).delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CategoryBudget>> getBudgets(DateTime date) async {
    final month = _monthKey(date);
    final rows = await (await database).query(
      'budgets',
      where: 'month = ?',
      whereArgs: [month],
      orderBy: 'category',
    );
    return rows.map(CategoryBudget.fromMap).toList();
  }

  Future<void> saveBudget(CategoryBudget budget) async {
    await (await database).insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeBudget(String category, DateTime date) async {
    await (await database).delete(
      'budgets',
      where: 'category = ? AND month = ?',
      whereArgs: [category, _monthKey(date)],
    );
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
