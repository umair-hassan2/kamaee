enum KhataEntryType { credit, payment } // credit = customer owes money, payment = customer paid

class KhataEntry {
  final int? id;
  final int customerId;
  final KhataEntryType type;
  final double amount;
  final String? note;
  final int timestamp;

  const KhataEntry({
    this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'customer_id': customerId,
    'type': type.name,
    'amount': amount,
    'note': note,
    'timestamp': timestamp,
  };

  factory KhataEntry.fromMap(Map<String, dynamic> map) => KhataEntry(
    id: map['id'] as int?,
    customerId: map['customer_id'] as int,
    type: KhataEntryType.values.firstWhere((e) => e.name == map['type']),
    amount: (map['amount'] as num).toDouble(),
    note: map['note'] as String?,
    timestamp: map['timestamp'] as int,
  );
}
