import 'dart:convert';
import 'dart:html' as html;

import '../models/category_budget.dart';
import '../models/expense.dart';

/// Browser-local storage adapter for the hosted demo.
/// Android builds use SQLite through expense_database.dart instead.
class ExpenseDatabase {
  ExpenseDatabase._();

  static final instance = ExpenseDatabase._();
  static const _expenseKey = 'receiptwise.vnd.expenses';
  static const _budgetKey = 'receiptwise.vnd.budgets';

  Future<List<Expense>> getAll() async {
    final rows = _readList(_expenseKey);
    return rows.map((row) => Expense.fromMap(row)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> insert(Expense expense) async {
    final rows = _readList(_expenseKey);
    final nextId = rows.fold<int>(0, (maxId, row) {
      final id = row['id'] as int? ?? 0;
      return id > maxId ? id : maxId;
    }) + 1;
    rows.add({...expense.toMap(), 'id': nextId});
    _writeList(_expenseKey, rows);
  }

  Future<void> delete(int id) async {
    final rows = _readList(_expenseKey)..removeWhere((row) => row['id'] == id);
    _writeList(_expenseKey, rows);
  }

  Future<List<CategoryBudget>> getBudgets(DateTime date) async {
    final month = _monthKey(date);
    return _readList(_budgetKey)
        .where((row) => row['month'] == month)
        .map(CategoryBudget.fromMap)
        .toList();
  }

  Future<void> saveBudget(CategoryBudget budget) async {
    final rows = _readList(_budgetKey)
      ..removeWhere((row) =>
          row['month'] == budget.month && row['category'] == budget.category);
    rows.add(budget.toMap());
    _writeList(_budgetKey, rows);
  }

  Future<void> removeBudget(String category, DateTime date) async {
    final month = _monthKey(date);
    final rows = _readList(_budgetKey)
      ..removeWhere(
          (row) => row['month'] == month && row['category'] == category);
    _writeList(_budgetKey, rows);
  }

  List<Map<String, Object?>> _readList(String key) {
    final raw = html.window.localStorage[key];
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
  }

  void _writeList(String key, List<Map<String, Object?>> rows) {
    html.window.localStorage[key] = jsonEncode(rows);
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
