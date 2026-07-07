class Item {
  final int? id;
  final String barcode;
  final String name;
  final double purchasePrice;
  final double sellingPrice;
  int quantity;

  Item({
    this.id,
    required this.barcode,
    required this.name,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) "id": id,
      "barcode": barcode,
      "name": name,
      "purchase_price": purchasePrice,
      "selling_price": sellingPrice,
      "quantity": quantity,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map["id"] as int?,
      barcode: map["barcode"] as String,
      name: map["name"] as String,
      purchasePrice: (map["purchase_price"] as num).toDouble(),
      sellingPrice: (map["selling_price"] as num).toDouble(),
      quantity: map["quantity"] as int,
    );
  }

  Item copyWith({int? id, String? barcode, String? name, double? purchasePrice, double? sellingPrice, int? quantity}) {
    return Item(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}
