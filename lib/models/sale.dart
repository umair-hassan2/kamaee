enum SaleStatus { draft, completed }

enum PaymentMethod { cash, khata, partial }

class Sale {
  final int? id;
  final int? customerId;
  final double totalAmount;
  final double paidAmount;
  final double khataAmount;
  final double discountAmount;
  final PaymentMethod paymentMethod;
  final SaleStatus status;
  final int timestamp;
  final bool isReturned;

  const Sale({
    this.id,
    this.customerId,
    required this.totalAmount,
    required this.paidAmount,
    required this.khataAmount,
    this.discountAmount = 0,
    required this.paymentMethod,
    required this.status,
    required this.timestamp,
    this.isReturned = false,
  });

  Sale copyWith({
    int? id,
    int? customerId,
    double? totalAmount,
    double? paidAmount,
    double? khataAmount,
    double? discountAmount,
    PaymentMethod? paymentMethod,
    SaleStatus? status,
    int? timestamp,
    bool? isReturned,
  }) {
    return Sale(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      khataAmount: khataAmount ?? this.khataAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isReturned: isReturned ?? this.isReturned,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'customer_id': customerId,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'khata_amount': khataAmount,
        'discount_amount': discountAmount,
        'payment_method': paymentMethod.name,
        'status': status.name,
        'timestamp': timestamp,
        'is_returned': isReturned ? 1 : 0,
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as int?,
        customerId: map['customer_id'] as int?,
        totalAmount: (map['total_amount'] as num).toDouble(),
        paidAmount: (map['paid_amount'] as num).toDouble(),
        khataAmount: (map['khata_amount'] as num).toDouble(),
        discountAmount: (map['discount_amount'] as num? ?? 0).toDouble(),
        paymentMethod: PaymentMethod.values.byName(map['payment_method'] as String),
        status: SaleStatus.values.byName(map['status'] as String),
        timestamp: map['timestamp'] as int,
        isReturned: (map['is_returned'] as int? ?? 0) == 1,
      );
}
