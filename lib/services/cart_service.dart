import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/cart_models.dart';
import 'auth_service.dart';

class CartService {
  static String get _baseUrl =>
      dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000/api';

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

  static Map<String, dynamic>? _tryDecode(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  static Future<RemoteCart> fetchCart() async {
    final res = await AuthService.authorizedRequest(
      (headers) => http.get(Uri.parse('$_baseUrl/cart'), headers: headers),
    );

    final body = _tryDecode(res);
    print('🔍 FULL CART RESPONSE: ${jsonEncode(body)}');

    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        body?['success'] == true) {
      final data = body!['data'] as Map<String, dynamic>;
      return RemoteCart.fromJson(data['cart'] as Map<String, dynamic>);
    }
    throw _errorFrom(res);
  }

  static Future<RemoteCartItem> addItem(
    String productId, {
    int quantity = 1,
  }) async {
    final res = await AuthService.authorizedRequest(
      (headers) => http.post(
        Uri.parse('$_baseUrl/cart/items'),
        headers: headers,
        body: jsonEncode({'product_id': productId, 'quantity': quantity}),
      ),
    );

    final body = _tryDecode(res);
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        body?['success'] == true) {
      final data = body!['data'] as Map<String, dynamic>;
      return RemoteCartItem.fromJson(data['item'] as Map<String, dynamic>);
    }
    throw _errorFrom(res);
  }

  static Future<RemoteCartItem> updateItemQuantity(
    String cartItemId,
    int quantity,
  ) async {
    final res = await AuthService.authorizedRequest(
      (headers) => http.patch(
        Uri.parse('$_baseUrl/cart/items/$cartItemId'),
        headers: headers,
        body: jsonEncode({'quantity': quantity}),
      ),
    );

    final body = _tryDecode(res);
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        body?['success'] == true) {
      final data = body!['data'] as Map<String, dynamic>;
      return RemoteCartItem.fromJson(data['item'] as Map<String, dynamic>);
    }
    throw _errorFrom(res);
  }

  static Future<void> removeItem(String cartItemId) async {
    final res = await AuthService.authorizedRequest(
      (headers) => http.delete(
        Uri.parse('$_baseUrl/cart/items/$cartItemId'),
        headers: headers,
      ),
    );

    final body = _tryDecode(res);
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        body?['success'] == true) {
      return;
    }
    throw _errorFrom(res);
  }
}
