class CartItemModel {
  final String id;
  final String name;
  final String details;
  final String imageUrl;
  final double price;
  final List<double>? prices;
  int quantity;

  CartItemModel({
    required this.id,
    required this.name,
    required this.details,
    required this.imageUrl,
    required this.price,
    this.prices,
    this.quantity = 1,
  });

  CartItemModel copyWith({
    String? id,
    String? name,
    String? details,
    String? imageUrl,
    double? price,
    List<double>? prices,
    int? quantity,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      details: details ?? this.details,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      prices: prices ?? this.prices,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'details': details,
      'imageUrl': imageUrl,
      'price': price,
      'prices': prices,
      'quantity': quantity,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      details: json['details'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      prices: (json['prices'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}
