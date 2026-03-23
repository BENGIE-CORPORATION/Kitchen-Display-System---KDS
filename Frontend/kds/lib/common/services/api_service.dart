import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class ApiService {
  //static const String baseUrl = BASE_URL;
  static final String _baseUrl = 
    dotenv.env['BASE_URL'] ?? 'http://localhost:8000/api/v1';

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  // ── Headers con token ──────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── GET ────────────────────────────────────────────────────────────────────
  static Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  // ── POST ───────────────────────────────────────────────────────────────────
  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  // ── PUT ────────────────────────────────────────────────────────────────────
  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  static Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  // ── Handler central de respuestas ─────────────────────────────────────────
  static dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return jsonDecode(response.body);

      case 401:
        // Token expirado — AuthProvider.checkSession() redirige a login
        throw ApiException(401, 'Sesión expirada. Inicia sesión nuevamente.');

      case 403:
        throw ApiException(403, 'No tienes permisos para esta acción.');

      case 404:
        throw ApiException(404, 'Recurso no encontrado.');

      case 422:
        final body = jsonDecode(response.body);
        final detail = body['detail'];
        final msg = detail is List
            ? (detail.first['msg'] ?? 'Error de validación')
            : detail?.toString() ?? 'Error de validación';
        throw ApiException(422, msg);

      case 429:
        throw ApiException(429, 'Demasiados intentos. Espera un momento.');

      default:
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        throw ApiException(
          response.statusCode,
          body['detail']?.toString() ?? 'Error del servidor (${response.statusCode})',
        );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}
