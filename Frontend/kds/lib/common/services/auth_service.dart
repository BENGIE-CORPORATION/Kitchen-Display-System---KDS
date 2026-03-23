import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/auth_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Claves usadas en secure storage
const _kAccessToken  = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kExpiresAt    = 'expires_at'; // epoch en segundos

class AuthService {
  //static const String _baseUrl = BASE_URL;
  static final String _baseUrl = 
    dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
  static const _storage = FlutterSecureStorage();

  // ── Login ──────────────────────────────────────────────────────────────────
  static Future<TokenResponse> login(LoginRequest request) async {    
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      final token = TokenResponse.fromJson(jsonDecode(response.body));
      await _saveTokens(token);
      return token;
    }

    final body = jsonDecode(response.body);
    throw AuthException(body['detail'] ?? 'Email o contraseña incorrectos');
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      final token = await getAccessToken();
      if (token != null) {
        await http.post(
          Uri.parse('$_baseUrl/api/v1/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (_) {
      // Aunque falle el request, borramos el token local igual
    } finally {
      await _clearTokens();
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────
  static Future<TokenResponse?> refreshSession() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final token = TokenResponse.fromJson(jsonDecode(response.body));
        await _saveTokens(token);
        return token;
      }
    } catch (_) {}

    // Si el refresh falla, limpiamos la sesión
    await _clearTokens();
    return null;
  }

  // ── Token helpers ──────────────────────────────────────────────────────────

  /// Devuelve el access token vigente.
  /// Si está por vencer (< 60s), intenta refrescarlo automáticamente.
  static Future<String?> getAccessToken() async {
    final token     = await _storage.read(key: _kAccessToken);
    final expiresAt = await _storage.read(key: _kExpiresAt);

    if (token == null || expiresAt == null) return null;

    final expiry = int.tryParse(expiresAt) ?? 0;
    final now    = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Si vence en menos de 60 segundos → refrescar proactivamente
    if (expiry - now < 60) {
      final refreshed = await refreshSession();
      return refreshed?.accessToken;
    }

    return token;
  }

  /// Verifica si hay una sesión activa (hay token guardado y no expiró)
  static Future<bool> hasActiveSession() async {
    final token = await getAccessToken();
    return token != null;
  }

  // ── Storage privado ────────────────────────────────────────────────────────

  static Future<void> _saveTokens(TokenResponse token) async {
    final expiresAt =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + token.expiresIn;

    await Future.wait([
      _storage.write(key: _kAccessToken,  value: token.accessToken),
      _storage.write(key: _kRefreshToken, value: token.refreshToken),
      _storage.write(key: _kExpiresAt,    value: expiresAt.toString()),
    ]);
  }

  static Future<void> _clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kExpiresAt),
    ]);
  }
}

/// Excepción con el mensaje del backend
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
