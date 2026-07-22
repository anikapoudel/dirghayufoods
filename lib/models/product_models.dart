import 'category_models.dart';

class Product {
  final String id;
  final String title;
  final String slug;
  final double price;
  final double? discountPrice;
  final String description;
  final int stock;
  final int orderQuantity;
  final String weight;
  final List<String> ingredients;
  final String status;
  final String imageUrl;
  final String expDate;
  final String manufactureDate;
  final Category category;

  Product({
    required this.id,
    required this.title,
    required this.slug,
    required this.price,
    this.discountPrice,
    required this.description,
    required this.stock,
    required this.orderQuantity,
    required this.weight,
    required this.ingredients,
    required this.status,
    required this.imageUrl,
    required this.expDate,
    required this.manufactureDate,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      price: double.parse(json['price']?.toString() ?? '0'),
      discountPrice: json['discount_price'] != null
          ? double.parse(json['discount_price'].toString())
          : null,
      description: json['description'] ?? '',
      stock: json['stock'] ?? 0,
      orderQuantity: json['order_quantity'] ?? 0,
      weight: json['weight'] ?? '',
      ingredients: json['ingredients'] != null
          ? List<String>.from(json['ingredients'])
          : [],
      status: json['status'] ?? '',
      imageUrl: json['image_url'] ?? '',
      expDate: json['exp_date'] ?? '',
      manufactureDate: json['manufacture_date'] ?? '',
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : Category(id: '', name: '', slug: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'price': price,
      'discount_price': discountPrice,
      'description': description,
      'stock': stock,
      'order_quantity': orderQuantity,
      'weight': weight,
      'ingredients': ingredients,
      'status': status,
      'image_url': imageUrl,
      'exp_date': expDate,
      'manufacture_date': manufactureDate,
      'category': category.toJson(),
    };
  }
}
