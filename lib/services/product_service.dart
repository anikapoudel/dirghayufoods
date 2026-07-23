import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/product_models.dart';
import 'auth_service.dart';

class ProductService {
  static String get _baseUrl =>
      dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000/api';

  static Future<Product> getProduct(String id) async {
    try {
      print('🔍 FETCHING PRODUCT: $id');

      final res = await AuthService.authorizedRequest(
        (headers) =>
            http.get(Uri.parse('$_baseUrl/products/$id'), headers: headers),
      );

      print('📡 PRODUCT STATUS: ${res.statusCode}');
      print('📡 PRODUCT BODY: ${res.body}');

      final body = _tryDecode(res);

      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body?['success'] == true) {
        final data = body!['data'] as Map<String, dynamic>;
        final productData = data['products'] as Map<String, dynamic>;
        return Product.fromJson(productData);
      }
      throw _errorFrom(res);
    } catch (e) {
      print('❌ ERROR fetching product $id: $e');
      rethrow;
    }
  }

  static Future<List<Product>> getAllProducts({int limit = 100}) async {
    try {
      final res = await AuthService.authorizedRequest(
        (headers) => http.get(
          Uri.parse('$_baseUrl/products?limit=$limit'),
          headers: headers,
        ),
      );

      final body = _tryDecode(res);

      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body?['success'] == true) {
        final data = body!['data'] as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>? ?? [];
        return products
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ ERROR fetching all products: $e');
      return [];
    }
  }

  static Map<String, dynamic>? _tryDecode(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  static Exception _errorFrom(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      final message = body is Map
          ? (body['message']?.toString() ?? 'Request failed')
          : 'Request failed';
      return Exception(message);
    } catch (_) {
      return Exception('Request failed (${res.statusCode})');
    }
  }
}
