import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_models.dart';
import '../models/category_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaginationInfo {
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  PaginationInfo({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? json['total_pages'] ?? 1,
      hasNextPage: json['hasNextPage'] ?? json['has_next_page'] ?? false,
      hasPrevPage: json['hasPrevPage'] ?? json['has_prev_page'] ?? false,
    );
  }
}

class PaginatedProducts {
  final List<Product> products;
  final PaginationInfo pagination;

  PaginatedProducts({required this.products, required this.pagination});
}

class ApiService {
  static final String baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:5000/api';

  // Fetch all products
  static Future<List<Product>> fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          List<dynamic> productsData = data['data']['products'];
          return productsData.map((json) => Product.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch products');
        }
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching products: $e');
    }
  }

  static Future<PaginatedProducts> fetchProductsPaginated({
    int page = 1,
    int limit = 10,
    String? category,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (category != null && category.isNotEmpty) 'category': category,
      };
      final uri = Uri.parse('$baseUrl/products').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> productsData = data['data']['products'];
          final products = productsData.map((json) => Product.fromJson(json)).toList();

          final paginationJson = data['data']['pagination'] as Map<String, dynamic>?;
          final pagination = paginationJson != null
              ? PaginationInfo.fromJson(paginationJson)
              : PaginationInfo(
            total: products.length,
            page: page,
            limit: limit,
            totalPages: 1,
            hasNextPage: false,
            hasPrevPage: false,
          );

          return PaginatedProducts(products: products, pagination: pagination);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch products');
        }
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching products: $e');
    }
  }

  // Fetch categories
  static Future<List<Category>> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          List<dynamic> categoriesData = data['data']['categories'];
          return categoriesData.map((json) => Category.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch categories');
        }
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  // Fetch products by category
  static Future<List<Product>> fetchProductsByCategory(String categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products?category=$categoryId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          List<dynamic> productsData = data['data']['products'];
          return productsData.map((json) => Product.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch products');
        }
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching products: $e');
    }
  }

  // Search products
  static Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/search?q=$query'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          List<dynamic> productsData = data['data']['products'];
          return productsData.map((json) => Product.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to search products');
        }
      } else {
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching products: $e');
    }
  }
}