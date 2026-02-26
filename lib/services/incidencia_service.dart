import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/incidencia.dart';

class IncidenciaService {
  static String get _baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return '${Uri.base.scheme}://$host:8000/api';
    }
    return 'http://192.168.1.39:8000/api';
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    return token;
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  String _extractError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return 'Error del servidor ($statusCode).';
  }

  /// GET /api/incidencias — listar incidencias/propuestas del usuario.
  Future<List<Incidencia>> fetchMisIncidencias() async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/incidencias');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is! List) {
      return [];
    }
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((item) => Incidencia.fromJson(item))
        .toList();
  }

  /// POST /api/incidencias — crear incidencia o propuesta.
  Future<Incidencia> crearIncidencia({
    required String tipo,
    String? contexto,
    int? recetaId,
    int? ingredienteId,
    required String asunto,
    required String cuerpo,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/incidencias');
    final body = <String, dynamic>{
      'tipo': tipo,
      'asunto': asunto,
      'cuerpo': cuerpo,
    };
    if (contexto != null && contexto.isNotEmpty) body['contexto'] = contexto;
    if (recetaId != null) body['receta_id'] = recetaId;
    if (ingredienteId != null) body['ingrediente_id'] = ingredienteId;

    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('No se devolvió la incidencia creada.');
    }
    return Incidencia.fromJson(data);
  }
}
