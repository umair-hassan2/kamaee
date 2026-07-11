class Customer {
  final int? id;
  final String name;
  final String phone;
  final int createdAt; // milliseconds since epoch
  final double balance; // computed, not stored in DB

  const Customer({
    this.id,
    required this.name,
    this.phone = '',
    required this.createdAt,
    this.balance = 0,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'phone': phone,
    'created_at': createdAt,
  };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'] as int?,
    name: map['name'] as String,
    phone: (map['phone'] as String?) ?? '',
    createdAt: map['created_at'] as int,
  );

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    int? createdAt,
    double? balance,
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    createdAt: createdAt ?? this.createdAt,
    balance: balance ?? this.balance,
  );
}
