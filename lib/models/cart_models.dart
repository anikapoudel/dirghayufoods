class RemoteCartProduct {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final double? discountPrice;
  final String status;

  const RemoteCartProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.discountPrice,
    required this.status,
  });

  double get effectivePrice => discountPrice ?? price;

  factory RemoteCartProduct.fromJson(Map<String, dynamic> json) {
    return RemoteCartProduct(
      id: json['id']?.toString() ?? '',
      name: json['title']?.toString() ?? json['name']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      discountPrice: json['discount_price'] != null
          ? double.tryParse(json['discount_price'].toString())
          : null,
      imageUrl: json['image_url']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class RemoteCartItem {
  final String id;
  final int quantity;
  final RemoteCartProduct product;

  const RemoteCartItem({
    required this.id,
    required this.quantity,
    required this.product,
  });

  double get unitPrice => product.effectivePrice;

  double get lineTotal => unitPrice * quantity;

  factory RemoteCartItem.fromJson(Map<String, dynamic> json) {
    return RemoteCartItem(
      id: json['id']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      product: RemoteCartProduct.fromJson(
        json['product'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class RemoteCart {
  final String id;
  final String customerId;
  final List<RemoteCartItem> items;

  const RemoteCart({
    required this.id,
    required this.customerId,
    required this.items,
  });

  factory RemoteCart.fromJson(Map<String, dynamic> json) {
    return RemoteCart(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => RemoteCartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory RemoteCart.empty() =>
      const RemoteCart(id: '', customerId: '', items: []);
}
