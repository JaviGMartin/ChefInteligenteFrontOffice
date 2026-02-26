import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

class RecipeService {
  // Android emulator must use 10.0.2.2 to reach host machine.
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api';

  // TODO: replace with your machine IP if needed.
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

  /// Convierte imagen_url (URL externa o path) en URL completa para mostrar.
  /// Usa /api/public-file/ para paths de storage (evita CORS en Flutter Web).
  String? recipeImageUrl(String? imagenUrl) {
    if (imagenUrl == null || imagenUrl.isEmpty) return null;
    if (imagenUrl.startsWith('http://') || imagenUrl.startsWith('https://')) {
      return imagenUrl;
    }
    final path = imagenUrl.startsWith('/') ? imagenUrl.substring(1) : imagenUrl;
    return '$baseUrl/public-file/$path';
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

  Future<List<Recipe>> fetchRecipes() async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl/recipes');
    final response = await http.get(uri, headers: _headers(token: token));

    if (response.statusCode != 200) {
      throw Exception('Failed to load recipes: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];

    if (data is! List) {
      return [];
    }

    final list = data
        .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
        .toList();
    return list;
  }

  /// Recetas que el usuario ha guardado en el planificador (pestaña Cocina).
  /// Incluye estado_salud, porcentaje_stock, es_cocinable para el hogar activo.
  Future<List<Recipe>> fetchPlanificador() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return [];
    }
    final uri = Uri.parse('$baseUrl/recipes/planificador');
    final response = await http.get(uri, headers: _headers(token: token));

    if (response.statusCode != 200) {
      throw Exception('Error al cargar el planificador: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];
    if (data is! List) {
      return [];
    }
    return data
        .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Receta por ID con ingredientes completos (cantidad, unidad). Para detalle desde Cocina.
  Future<Recipe> getRecipe(int id) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$id');
    final response = await http.get(uri, headers: _headers(token: token));
    if (response.statusCode == 404) {
      throw Exception('Receta no encontrada.');
    }
    if (response.statusCode != 200) {
      throw Exception('Error al cargar la receta: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] as Map<String, dynamic>;
    return Recipe.fromJson(data);
  }

  /// Lista ingredientes (id, nombre) para formularios de creación de recetas.
  Future<List<Ingredient>> fetchIngredientes() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para crear recetas.');
    }
    final uri = Uri.parse('$baseUrl/ingredientes');
    final response = await http.get(uri, headers: _headers(token: token));

    if (response.statusCode != 200) {
      throw Exception('Error al cargar ingredientes: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];
    if (data is! List) return [];
    return data
        .map((item) => Ingredient.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Crea una receta (borrador).
  /// [ingredientes]: lista de {ingrediente_id, cantidad, unidad_medida_id?}.
  /// [elaboraciones]: opcional, [{titulo, orden?, pasos: [{descripcion, tiempo_segundos?, temperatura?, orden?, ingredientes?: [...]}]}].
  Future<Recipe> createRecipe({
    required String titulo,
    String? descripcion,
    String? instrucciones,
    String? imagenUrl,
    int? tiempoPreparacion,
    String? dificultad,
    int? porcionesBase,
    List<String>? herramientas,
    List<Map<String, dynamic>>? ingredientes,
    List<Map<String, dynamic>>? elaboraciones,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para crear recetas.');
    }
    final uri = Uri.parse('$baseUrl/recipes');
    final body = <String, dynamic>{
      'titulo': titulo,
      if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
      if (instrucciones != null && instrucciones.isNotEmpty) 'instrucciones': instrucciones,
      if (imagenUrl != null && imagenUrl.isNotEmpty) 'imagen_url': imagenUrl,
      if (tiempoPreparacion != null) 'tiempo_preparacion': tiempoPreparacion,
      if (dificultad != null && dificultad.isNotEmpty) 'dificultad': dificultad,
      if (porcionesBase != null) 'porciones_base': porcionesBase,
      if (herramientas != null && herramientas.isNotEmpty) 'herramientas': herramientas,
      if (ingredientes != null && ingredientes.isNotEmpty) 'ingredientes': ingredientes,
      if (elaboraciones != null && elaboraciones.isNotEmpty) 'elaboraciones': elaboraciones,
    };
    final response = await http.post(
      uri,
      headers: _headers(token: token)..['Content-Type'] = 'application/json',
      body: jsonEncode(body),
    );

    if (response.statusCode == 422 || response.statusCode == 403) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = decoded?['message'] as String? ?? 'No se pudo crear la receta.';
      throw Exception(message);
    }
    if (response.statusCode != 201) {
      throw Exception('Error al crear receta: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta inválida del servidor.');
    return Recipe.fromJson(data);
  }

  /// Envía los ingredientes faltantes de la receta al embudo de pendientes del hogar activo.
  /// El backend usa el hogar activo del usuario (user.hogar_id), no hace falta enviarlo en el body.
  Future<void> enviarAPendientes(int recipeId, {int? porcionesDeseadas}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para planificar esta receta.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$recipeId/enviar-a-pendientes');
    final body = <String, dynamic>{};
    if (porcionesDeseadas != null) body['porciones_deseadas'] = porcionesDeseadas;
    final response = await http.post(
      uri,
      headers: _headers(token: token)..['Content-Type'] = 'application/json',
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    // Debug: imprimir body cuando falla para ver validación del backend
    if (kDebugMode) {
      // ignore: avoid_print
      print('enviarAPendientes $recipeId: ${response.statusCode} ${response.body}');
    }

    String message = 'No se pudo enviar a pendientes.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['message'] as String? ?? message;
      }
    } catch (_) {}

    if (response.statusCode == 422 || response.statusCode == 403) {
      throw Exception(message);
    }
    throw Exception('$message (${response.statusCode})');
  }

  /// Guarda la receta en el Planificador del usuario (Modo Guardar – Propuesta 1).
  Future<void> guardarEnPlanificador(int recipeId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para guardar en el Planificador.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$recipeId/planificador');
    final response = await http.post(
      uri,
      headers: _headers(token: token)..['Content-Type'] = 'application/json',
      body: jsonEncode({}),
    );

    if (response.statusCode == 403 || response.statusCode == 422) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = decoded?['message'] as String? ?? 'No se pudo guardar.';
      throw Exception(message);
    }
    if (response.statusCode != 200) {
      throw Exception('Error al guardar en planificador: ${response.statusCode}');
    }
  }

  /// Quita la receta del Planificador del usuario.
  Future<void> quitarDelPlanificador(int recipeId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para modificar el Planificador.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$recipeId/planificador');
    final response = await http.delete(uri, headers: _headers(token: token));

    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = decoded?['message'] as String? ?? 'Error al quitar del planificador.';
      throw Exception(message);
    }
  }

  /// Actualiza una receta (solo borrador/rechazada propias).
  /// Body: titulo, descripcion, instrucciones, imagen_url, tiempo_preparacion, dificultad, porciones_base, ingredientes, elaboraciones.
  Future<Recipe> updateRecipe({
    required int recipeId,
    required String titulo,
    String? descripcion,
    String? instrucciones,
    String? imagenUrl,
    int? tiempoPreparacion,
    String? dificultad,
    int? porcionesBase,
    List<String>? herramientas,
    List<Map<String, dynamic>>? ingredientes,
    List<Map<String, dynamic>>? elaboraciones,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para editar recetas.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$recipeId');
    final body = <String, dynamic>{
      'titulo': titulo.trim(),
      'descripcion': descripcion ?? '',
      'instrucciones': instrucciones ?? '',
      'imagen_url': imagenUrl ?? '',
      if (tiempoPreparacion != null) 'tiempo_preparacion': tiempoPreparacion is int ? tiempoPreparacion : (tiempoPreparacion.round()),
      'dificultad': (dificultad != null && dificultad.isNotEmpty) ? dificultad : null,
      if (porcionesBase != null) 'porciones_base': porcionesBase,
      if (herramientas != null) 'herramientas': herramientas,
    };
    if (ingredientes != null && ingredientes.isNotEmpty) {
      body['ingredientes'] = ingredientes.map((e) {
        final id = e['ingrediente_id'];
        final cantidad = e['cantidad'];
        final umId = e['unidad_medida_id'];
        final row = <String, dynamic>{
          'ingrediente_id': id is int ? id : (id is num ? id.toInt() : int.tryParse(id?.toString() ?? '') ?? 0),
          'cantidad': cantidad is num ? cantidad : (double.tryParse(cantidad?.toString() ?? '') ?? 0.0),
        };
        if (umId != null) row['unidad_medida_id'] = umId is int ? umId : (umId is num ? umId.toInt() : int.tryParse(umId.toString()) ?? 1);
        return row;
      }).toList();
    }
    if (elaboraciones != null && elaboraciones.isNotEmpty) {
      body['elaboraciones'] = elaboraciones;
    }
    final bodyJson = jsonEncode(body);
    debugPrint('[RecipeService.updateRecipe] PUT $uri');
    debugPrint('[RecipeService.updateRecipe] body: $bodyJson');
    final response = await http.put(
      uri,
      headers: _headers(token: token)..['Content-Type'] = 'application/json',
      body: bodyJson,
    );

    if (response.statusCode == 422 || response.statusCode == 403) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = decoded?['message'] as String? ?? 'No se pudo actualizar la receta.';
      throw Exception(message);
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al actualizar receta: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta inválida del servidor.');
    return Recipe.fromJson(data);
  }

  /// Borra una receta propia (solo borrador, rechazada o pendiente; no si está en planificador).
  Future<void> deleteRecipe(int recipeId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para borrar recetas.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$recipeId');
    final response = await http.delete(uri, headers: _headers(token: token));

    if (response.statusCode == 422 || response.statusCode == 403) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = decoded?['message'] as String? ?? 'No se pudo borrar la receta.';
      throw Exception(message);
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al borrar receta: ${response.statusCode}');
    }
  }

  /// Marca la receta como cocinada y descuenta el stock del inventario del hogar activo.
  Future<void> marcarCocinada(int recipeId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para marcar la receta como cocinada.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$recipeId/marcar-cocinada');
    final response = await http.post(
      uri,
      headers: _headers(token: token),
    );

    if (response.statusCode == 422 || response.statusCode == 403) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = decoded?['message'] as String? ?? 'No se pudo marcar como cocinada.';
      throw Exception(message);
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al marcar como cocinada: ${response.statusCode}');
    }
  }

  /// Solicita publicación: pasa la receta a estado pendiente (en revisión). Solo autor, borrador o rechazada.
  Future<Recipe> solicitarPublicacion(int recipeId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para solicitar publicación.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$recipeId/solicitar-publicacion');
    final response = await http.patch(
      uri,
      headers: _headers(token: token)..['Content-Type'] = 'application/json',
    );

    if (response.statusCode == 422 || response.statusCode == 403) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = decoded?['message'] as String? ?? 'No se pudo solicitar la publicación.';
      throw Exception(message);
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al solicitar publicación: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta inválida del servidor.');
    return Recipe.fromJson(data);
  }

  /// Volver a borrador: pasa la receta de pendiente (en revisión) a borrador.
  /// Útil cuando el autor se da cuenta de que falta algo antes de que el admin la publique.
  Future<Recipe> volverABorrador(int recipeId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión.');
    }
    final uri = Uri.parse('$baseUrl/recipes/$recipeId/volver-a-borrador');
    final response = await http.patch(
      uri,
      headers: _headers(token: token)..['Content-Type'] = 'application/json',
    );

    if (response.statusCode == 422 || response.statusCode == 403) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = decoded?['message'] as String? ?? 'No se pudo volver a borrador.';
      throw Exception(message);
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al volver a borrador: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta inválida del servidor.');
    return Recipe.fromJson(data);
  }
}
