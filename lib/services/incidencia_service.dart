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
  /// [archived] true = solo archivadas, false/omitido = solo activas.
  Future<List<Incidencia>> fetchMisIncidencias({bool archived = false}) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/incidencias').replace(
      queryParameters: archived ? {'archived': '1'} : {},
    );
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

  /// GET /api/incidencias/unread-count — cuenta para badge (respuestas del equipo).
  Future<int> fetchUnreadCount() async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('$_baseUrl/incidencias/unread-count');
      final response = await http.get(uri, headers: _authHeaders(token));
      if (response.statusCode != 200) return 0;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final c = decoded['count'];
      return (c is num) ? c.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// PATCH /api/incidencias/{id}/estado — actualizar estado (resuelto, cerrado).
  Future<Incidencia> updateEstado(int id, String estado) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/incidencias/$id/estado');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'estado': estado}),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No se devolvió la incidencia.');
    return Incidencia.fromJson(data);
  }

  /// PATCH /api/incidencias/{id}/archive — archivar incidencia.
  Future<void> archivarIncidencia(int id) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/incidencias/$id/archive');
    final response = await http.patch(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// GET /api/incidencias/{id} — una incidencia (para refrescar detalle).
  Future<Incidencia> getIncidencia(int id) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/incidencias/$id');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Incidencia no encontrada.');
    return Incidencia.fromJson(data);
  }

  /// POST /api/incidencias/{id}/mensajes — añadir respuesta del usuario.
  Future<Incidencia> addMensaje(int id, String mensaje) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/incidencias/$id/mensajes');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'mensaje': mensaje}),
    );
    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No se devolvió la incidencia.');
    return Incidencia.fromJson(data);
  }

  /// DELETE /api/incidencias/{id} — eliminar incidencia.
  Future<void> eliminarIncidencia(int id) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/incidencias/$id');
    final response = await http.delete(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }
}
