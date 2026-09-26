class StockCount {
  final int? id;
  final int itemId;
  final String itemName;
  final int systemQty;
  final int physicalQty;
  final int variance;
  final int countedAt;

  const StockCount({
    this.id,
    required this.itemId,
    required this.itemName,
    required this.systemQty,
    required this.physicalQty,
    required this.variance,
    required this.countedAt,
  });

  bool get isShort => variance < 0;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'item_id': itemId,
    'item_name': itemName,
    'system_qty': systemQty,
    'physical_qty': physicalQty,
    'variance': variance,
    'counted_at': countedAt,
  };

  factory StockCount.fromMap(Map<String, dynamic> map) => StockCount(
    id: map['id'] as int?,
    itemId: map['item_id'] as int,
    itemName: map['item_name'] as String,
    systemQty: map['system_qty'] as int,
    physicalQty: map['physical_qty'] as int,
    variance: map['variance'] as int,
    countedAt: map['counted_at'] as int,
  );
}
