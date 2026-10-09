class Expense {
  const Expense({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
  });

  final int? id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;

  Map<String, Object?> toMap() => {
        'id': id,
        'merchant': merchant,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
      };

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as int,
        merchant: map['merchant'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        category: map['category'] as String,
      );
}
