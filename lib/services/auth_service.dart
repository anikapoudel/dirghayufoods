import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_model.dart';
import 'package:flutter/foundation.dart';

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final String baseUrl =
      dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000/api';
  static bool _printedOnce = (() {
    print('🔍 AUTH BASE URL IS: $baseUrl');
    return true;
  })();
  static const String _cookieKey = 'auth_session_cookie';
  static const String _userDataKey = 'auth_user_data';

  static final ValueNotifier<int> authChangeTick = ValueNotifier<int>(0);

  static void _notifyAuthChanged() {
    authChangeTick.value++;
  }

  static Future<void> _saveCookieFromResponse(http.Response response) async {
    final setCookie = response.headers['set-cookie'];
    print('🍪 RAW SET-COOKIE: $setCookie');
    if (setCookie == null || setCookie.isEmpty) return;

    final cookieStrings = setCookie.split(RegExp(r',(?=\s*[^,;=\s]+=)'));
    final cookiePairs = cookieStrings
        .map((c) => c.split(';').first.trim())
        .where((c) => c.isNotEmpty && c.contains('='));
    final cookieString = cookiePairs.join('; ');

    if (cookieString.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookieKey, cookieString);
  }

  static Future<String?> _getStoredCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cookieKey);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookieKey);
    await prefs.remove(_userDataKey);
  }

  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, json.encode(userData));
  }

  static Future<Map<String, dynamic>?> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userDataKey);
    if (raw == null) return null;
    return json.decode(raw) as Map<String, dynamic>;
  }

  static Future<bool> hasSession() async {
    final cookie = await _getStoredCookie();
    return cookie != null && cookie.isNotEmpty;
  }

  static Future<bool> isLoggedIn() async {
    final userData = await getSavedUserData();
    return userData != null;
  }

  static Future<Map<String, String>> _headers({bool withAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final cookie = await _getStoredCookie();
      if (cookie != null) headers['Cookie'] = cookie;
    }
    return headers;
  }

  static Future<Map<String, String>> authHeaders() => _headers(withAuth: true);

  static Future<bool> refreshToken() async {
    http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: await _headers(withAuth: true),
      );
    } catch (_) {
      return false;
    }
    print('🔄 REFRESH STATUS: ${response.statusCode}');
    print('🔄 REFRESH BODY: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) return false;

    await _saveCookieFromResponse(response);

    try {
      final data = json.decode(response.body);
      return data is Map && data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<http.Response> authorizedRequest(
      Future<http.Response> Function(Map<String, String> headers) request,
      ) async {
    var headers = await authHeaders();
    var response = await request(headers);
    await _saveCookieFromResponse(response);

    final looksExpired =
        response.statusCode == 401 &&
            response.body.toLowerCase().contains('expired');

    if (looksExpired) {
      final refreshed = await refreshToken();
      if (refreshed) {
        headers = await authHeaders();
        response = await request(headers);
        await _saveCookieFromResponse(response);
      }
    }
    return response;
  }

  static Future<Map<String, dynamic>> _decode(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return Future.value(decoded);
      throw const FormatException('Unexpected response shape');
    } catch (_) {
      throw AuthException(
        'Unexpected response from server (${response.statusCode})',
      );
    }
  }

  static Future<Map<String, dynamic>> _post(
      String path,
      Map<String, dynamic> body, {
        bool withAuth = false,
        bool captureCookie = false,
      }) async {
    http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(withAuth: withAuth),
        body: json.encode(body),
      );
    } catch (_) {
      throw AuthException('Could not reach the server. Check your connection.');
    }
    print('📡 STATUS: ${response.statusCode}');
    print('📡 BODY: ${response.body}');

    if (captureCookie) await _saveCookieFromResponse(response);

    final data = await _decode(response);
    if (data['success'] == true) return data;
    throw AuthException(data['message']?.toString() ?? 'Something went wrong');
  }

  static Future<Map<String, dynamic>> _get(
      String path, {
        bool withAuth = false,
      }) async {
    http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(withAuth: withAuth),
      );
    } catch (_) {
      throw AuthException('Could not reach the server. Check your connection.');
    }

    final data = await _decode(response);
    if (data['success'] == true) return data;
    throw AuthException(data['message']?.toString() ?? 'Something went wrong');
  }

  static Future<Map<String, dynamic>> _patch(
      String path,
      Map<String, dynamic> body,
      ) async {
    http.Response response;
    try {
      response = await http.patch(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(withAuth: true),
        body: json.encode(body),
      );
    } catch (_) {
      throw AuthException('Could not reach the server. Check your connection.');
    }

    final data = await _decode(response);
    if (data['success'] == true) return data;
    throw AuthException(data['message']?.toString() ?? 'Something went wrong');
  }

  static Future<String> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String phone,
    required String location,
  }) async {
    final data = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
      'phone': phone,
      'location': location,
    });
    return data['message']?.toString() ??
        'Registered. Check your email for an OTP.';
  }

  static Future<String> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final data = await _post('/auth/verify-otp', {'email': email, 'otp': otp});
    return data['message']?.toString() ?? 'Email verified.';
  }

  static Future<String> resendOtp({required String email}) async {
    final data = await _post('/auth/resend-otp', {'email': email});
    return data['message']?.toString() ??
        'A new OTP has been sent to your email. Please verify to complete registration.';
  }

  static Future<Customer> login({
    required String email,
    required String password,
  }) async {
    final data = await _post(
      '/auth/login',
      {'email': email, 'password': password},
      withAuth: true,
      captureCookie: true,
    );

    final customerJson = data['data']?['customer'];
    if (customerJson == null) {
      throw AuthException('Login succeeded but the response was malformed.');
    }
    final customer = Customer.fromJson(customerJson);
    await saveUserData(customer.toJson());
    _notifyAuthChanged();
    return customer;
  }

  static Future<void> logout() async {
    try {
      await _post('/auth/logout', {}, withAuth: true);
    } catch (_) {
    } finally {
      await clearSession();
      _notifyAuthChanged();
    }
  }

  static Future<String> forgotPassword({required String email}) async {
    final data = await _post('/auth/forgot-password', {'email': email});
    return data['message']?.toString() ?? 'OTP sent to your email.';
  }

  static Future<String> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    final data = await _post('/auth/verify-reset-otp', {
      'email': email,
      'otp': otp,
    });
    return data['message']?.toString() ?? 'OTP verified.';
  }

  static Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final data = await _post('/auth/reset-password', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
    return data['message']?.toString() ?? 'Password reset successfully.';
  }

  static Future<Customer> getMe() async {
    final data = await _get('/auth/me', withAuth: true);
    return Customer.fromJson(data['data']['customer']);
  }

  static Future<Customer> updateMe({
    String? name,
    String? phone,
    String? location,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (location != null) body['location'] = location;

    final data = await _patch('/auth/me', body);
    return Customer.fromJson(data['data']['customer']);
  }
}