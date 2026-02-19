import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contenedor.dart';
import '../models/inventario.dart';
import '../models/unidad_medida.dart';

class StockService {
  static String get _baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return '${Uri.base.scheme}://$host:8000/api';
    }
    return 'http://192.168.1.39:8000/api';
  }

  Future<List<Contenedor>> fetchContenedores({int? hogarId}) async {
    final token = await _getToken();
    final query = hogarId != null ? '?hogar_id=$hogarId' : '';
    final uri = Uri.parse('$_baseUrl/contenedores$query');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => Contenedor.fromJson(item))
        .toList();
  }

  Future<List<Inventario>> fetchInventarios({
    int? hogarId,
    int? contenedorId,
  }) async {
    final token = await _getToken();
    String query = '';
    if (contenedorId != null) {
      query = '?contenedor_id=$contenedorId';
    } else if (hogarId != null) {
      query = '?hogar_id=$hogarId';
    }
    final uri = Uri.parse('$_baseUrl/inventarios$query');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => Inventario.fromJson(item))
        .toList();
  }

  Future<List<UnidadMedida>> fetchUnidadesMedida() async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/unidades-medida');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => UnidadMedida.fromJson(item))
        .toList();
  }

  Future<void> updateContenedor({
    required int id,
    required String nombre,
    required String tipo,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/contenedores/$id');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'nombre': nombre,
        'tipo': tipo,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<void> createContenedor({
    required int hogarId,
    required String nombre,
    required String tipo,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/contenedores');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'hogar_id': hogarId,
        'nombre': nombre,
        'tipo': tipo,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<void> deleteContenedor(int id) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/contenedores/$id');
    final response = await http.delete(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<void> updateInventario({
    required int id,
    required int contenedorId,
    required int unidadMedidaId,
    required double cantidad,
    String? fechaCaducidad,
    String? fechaApertura,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/inventarios/$id');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'contenedor_id': contenedorId,
        'unidad_medida_id': unidadMedidaId,
        'cantidad': cantidad,
        'fecha_caducidad': fechaCaducidad,
        'fecha_apertura': fechaApertura,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<void> deleteInventario(int id) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/inventarios/$id');
    final response = await http.delete(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesion no iniciada.');
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

    return 'Request failed ($statusCode).';
  }
}
