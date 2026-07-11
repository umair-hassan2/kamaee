class CashSession {
  final int? id;
  final double openingCash;
  final double? closingCash;
  final double? expectedCash;
  final double? discrepancy;
  final int openedAt;
  final int? closedAt;
  final String? notes;

  const CashSession({
    this.id,
    required this.openingCash,
    this.closingCash,
    this.expectedCash,
    this.discrepancy,
    required this.openedAt,
    this.closedAt,
    this.notes,
  });

  bool get isOpen => closedAt == null;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'opening_cash': openingCash,
    'closing_cash': closingCash,
    'expected_cash': expectedCash,
    'discrepancy': discrepancy,
    'opened_at': openedAt,
    'closed_at': closedAt,
    'notes': notes,
  };

  factory CashSession.fromMap(Map<String, dynamic> map) => CashSession(
    id: map['id'] as int?,
    openingCash: (map['opening_cash'] as num).toDouble(),
    closingCash: (map['closing_cash'] as num?)?.toDouble(),
    expectedCash: (map['expected_cash'] as num?)?.toDouble(),
    discrepancy: (map['discrepancy'] as num?)?.toDouble(),
    openedAt: map['opened_at'] as int,
    closedAt: map['closed_at'] as int?,
    notes: map['notes'] as String?,
  );
}
