import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order_models.dart';
import 'auth_service.dart';

class OrderService {
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

  static Future<CreateOrderResult> createOrder(
    CreateOrderRequest request,
  ) async {
    final res = await AuthService.authorizedRequest(
      (headers) => http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      ),
    );

    final body = _tryDecode(res);
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        body?['success'] == true) {
      return CreateOrderResult.fromJson(body!['data'] as Map<String, dynamic>);
    }
    throw _errorFrom(res);
  }

  static Future<OrderListResult> fetchMyOrders({
    int page = 1,
    int limit = 10,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/orders/my',
    ).replace(queryParameters: {'page': '$page', 'limit': '$limit'});
    final res = await AuthService.authorizedRequest(
      (headers) => http.get(uri, headers: headers),
    );

    final body = _tryDecode(res);
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        body?['success'] == true) {
      final data = body!['data'] as Map<String, dynamic>;
      final orders = (data['orders'] as List<dynamic>? ?? [])
          .map((e) => RemoteOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      final pagination = OrderPagination.fromJson(
        data['pagination'] as Map<String, dynamic>? ?? const {},
      );
      return OrderListResult(orders: orders, pagination: pagination);
    }
    throw _errorFrom(res);
  }

  static Future<RemoteOrder> fetchOrderById(String id) async {
    final res = await AuthService.authorizedRequest(
      (headers) =>
          http.get(Uri.parse('$_baseUrl/orders/my/$id'), headers: headers),
    );

    final body = _tryDecode(res);
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        body?['success'] == true) {
      final data = body!['data'] as Map<String, dynamic>;
      return RemoteOrder.fromJson(data['order'] as Map<String, dynamic>);
    }
    throw _errorFrom(res);
  }

  static Future<void> cancelOrder(String id) async {
    final res = await AuthService.authorizedRequest(
      (headers) => http.patch(
        Uri.parse('$_baseUrl/orders/my/$id/cancel'),
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
