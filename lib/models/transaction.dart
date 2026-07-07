enum TransactionType { sell, restock }

class SaleTransaction {
  final int? id;
  final int itemId;
  final String itemName;
  final TransactionType type;
  final int quantity;
  final double unitCost;
  final double unitPrice;
  final double revenue;
  final double cost;
  final double profit;
  final DateTime timestamp;

  const SaleTransaction({
    this.id,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.quantity,
    required this.unitCost,
    required this.unitPrice,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'item_id': itemId,
      'item_name': itemName,
      'type': type.name,
      'quantity': quantity,
      'unit_cost': unitCost,
      'unit_price': unitPrice,
      'revenue': revenue,
      'cost': cost,
      'profit': profit,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map) {
    return SaleTransaction(
      id: map['id'] as int?,
      itemId: map['item_id'] as int,
      itemName: map['item_name'] as String,
      type: TransactionType.values.byName(map['type'] as String),
      quantity: map['quantity'] as int,
      unitCost: (map['unit_cost'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      revenue: (map['revenue'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
      profit: (map['profit'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
