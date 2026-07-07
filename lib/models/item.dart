class Item {
  final int? id;
  final String barcode;
  final String name;
  final double purchasePrice;
  final double sellingPrice;
  int quantity;
  final String? photoPath;

  Item({
    this.id,
    required this.barcode,
    required this.name,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) "id": id,
      "barcode": barcode,
      "name": name,
      "purchase_price": purchasePrice,
      "selling_price": sellingPrice,
      "quantity": quantity,
      "photo_path": photoPath,
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
      photoPath: map["photo_path"] as String?,
    );
  }

  Item copyWith({
    int? id,
    String? barcode,
    String? name,
    double? purchasePrice,
    double? sellingPrice,
    int? quantity,
    String? photoPath,
    bool clearPhotoPath = false,
  }) {
    return Item(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
    );
  }
}
