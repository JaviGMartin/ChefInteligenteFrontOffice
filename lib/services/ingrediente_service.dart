import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

/// Categoría de ingrediente para el dropdown al proponer uno nuevo.
class CategoriaIngrediente {
  final int id;
  final String nombre;

  const CategoriaIngrediente({required this.id, required this.nombre});

  factory CategoriaIngrediente.fromJson(Map<String, dynamic> json) {
    return CategoriaIngrediente(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] as String?) ?? '',
    );
  }
}

class IngredienteService {
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
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return 'Error del servidor ($statusCode).';
  }

  /// GET /api/categorias-ingrediente — listado para dropdown al proponer ingrediente.
  Future<List<CategoriaIngrediente>> fetchCategoriasIngrediente() async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/categorias-ingrediente');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => CategoriaIngrediente.fromJson(item))
        .toList();
  }

  /// POST /api/ingredientes — crear ingrediente (propuesta). Visible solo para el usuario hasta que admin verifique.
  Future<Ingredient> crearIngrediente({
    required String nombre,
    required int categoriaIngredienteId,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/ingredientes');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'nombre': nombre.trim(),
        'categoria_ingrediente_id': categoriaIngredienteId,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('No se devolvió el ingrediente creado.');
    }
    return Ingredient(
      id: (data['id'] as num).toInt(),
      nombre: (data['nombre'] as String?) ?? nombre.trim(),
    );
  }
}
