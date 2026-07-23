import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ContactException implements Exception {
  final String message;

  ContactException(this.message);

  @override
  String toString() => message;
}

class ContactService {
  static final String baseUrl =
      dotenv.env['API_URL'] ?? 'http://localhost:5000/api';

  static Future<Map<String, dynamic>> submitInquiry({
    required String name,
    required String phone,
    required String message,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      'message': message,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };

    http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/contact'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
    } catch (_) {
      throw ContactException(
        'Could not reach the server. Check your connection.',
      );
    }

    Map<String, dynamic> data;
    try {
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected response shape');
      }
      data = decoded;
    } catch (_) {
      throw ContactException(
        'Unexpected response from server (${response.statusCode}).',
      );
    }

    if (data['success'] == true) return data;
    throw ContactException(
      data['message']?.toString() ?? 'Failed to send your message.',
    );
  }
}
