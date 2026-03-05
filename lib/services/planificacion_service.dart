import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/planificacion.dart';

class PlanificacionService {
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api';
  static const String _hostIp = '192.168.1.39';
  static const String _deviceBaseUrl = 'http://$_hostIp:8000/api';

  String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return '${Uri.base.scheme}://$host:8000/api';
    }
    if (!kIsWeb && Platform.isAndroid) {
      return _androidEmulatorBaseUrl;
    }
    return _deviceBaseUrl;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return (token != null && token.isNotEmpty) ? token : null;
  }

  Map<String, String> _headers({String? token}) {
    final map = <String, String>{'Accept': 'application/json'};
    if (token != null) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Respuesta del listado de planificaciones con flag de si el usuario puede editar el calendario.
  Future<({List<Planificacion> list, bool puedeEditarCalendario})> fetchPlanificaciones({
    required DateTime from,
    required DateTime to,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return (list: <Planificacion>[], puedeEditarCalendario: true);
    }
    final uri = Uri.parse('$baseUrl/planificaciones?from=${_fmt(from)}&to=${_fmt(to)}');
    final response = await http.get(uri, headers: _headers(token: token)).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException('El servidor no respondió. Comprueba que el backend esté en marcha y la URL sea correcta.'),
    );
    if (response.statusCode != 200) {
      final message = _extractMessage(response.body) ?? 'Error al cargar el calendario.';
      throw Exception(message);
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];
    List<Planificacion> list = [];
    if (data is List) {
      list = data
          .whereType<Map<String, dynamic>>()
          .map((item) => Planificacion.fromJson(item))
          .toList();
    }
    bool puedeEditarCalendario = true;
    final meta = payload['meta'];
    if (meta is Map<String, dynamic> && meta['puede_editar_calendario'] is bool) {
      puedeEditarCalendario = meta['puede_editar_calendario'] as bool;
    }
    return (list: list, puedeEditarCalendario: puedeEditarCalendario);
  }

  Future<void> crearPlanificacion({
    required int recetaId,
    required String fecha,
    required String toma,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión.');
    }
    final uri = Uri.parse('$baseUrl/planificaciones');
    final response = await http.post(
      uri,
      headers: _headers(token: token)..['Content-Type'] = 'application/json',
      body: jsonEncode({
        'receta_id': recetaId,
        'fecha': fecha,
        'toma': toma,
      }),
    );
    if (response.statusCode != 201) {
      final message = _extractMessage(response.body) ?? 'No se pudo planificar.';
      throw Exception(message);
    }
  }

  Future<void> eliminarPlanificacion(int id) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión.');
    }
    final uri = Uri.parse('$baseUrl/planificaciones/$id');
    final response = await http.delete(uri, headers: _headers(token: token));
    if (response.statusCode != 200) {
      final message = _extractMessage(response.body) ?? 'No se pudo eliminar la planificación.';
      throw Exception(message);
    }
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return null;
  }
}
