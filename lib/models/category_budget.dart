class CategoryBudget {
  const CategoryBudget({
    required this.category,
    required this.month,
    required this.limit,
  });

  final String category;
  final String month;
  final double limit;

  Map<String, Object?> toMap() => {
        'category': category,
        'month': month,
        'amount': limit,
      };

  factory CategoryBudget.fromMap(Map<String, Object?> map) => CategoryBudget(
        category: map['category'] as String,
        month: map['month'] as String,
        limit: (map['amount'] as num).toDouble(),
      );
}
