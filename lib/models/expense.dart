const List<String> expenseCategories = [
  'Rent',
  'Electricity',
  'Staff',
  'Packaging',
  'Transport',
  'Other',
];

class Expense {
  final int? id;
  final String category;
  final double amount;
  final String? note;
  final int timestamp;

  const Expense({
    this.id,
    required this.category,
    required this.amount,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'category': category,
    'amount': amount,
    'note': note,
    'timestamp': timestamp,
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as int?,
    category: map['category'] as String,
    amount: (map['amount'] as num).toDouble(),
    note: map['note'] as String?,
    timestamp: map['timestamp'] as int,
  );
}
