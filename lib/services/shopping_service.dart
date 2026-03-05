import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lista_compra.dart';
import '../models/pendiente_compra.dart';

/// Lanzada cuando se intenta asignar un producto de otro supermercado a una lista vinculada a un supermercado distinto.
class ProductoOtroSupermercadoException implements Exception {
  ProductoOtroSupermercadoException(this.proveedorId, this.proveedorNombre);
  final int proveedorId;
  final String proveedorNombre;
  @override
  String toString() => 'Producto de $proveedorNombre (proveedor_id: $proveedorId)';
}

class ShoppingService {
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api';
  static const String _hostIp = '192.168.1.39';
  static const String _deviceBaseUrl = 'http://$_hostIp:8000/api';

  final Map<String, List<UnidadMedidaCompleta>> _unidadesMedidaCache = {};
  final Map<String, Future<List<UnidadMedidaCompleta>>> _unidadesMedidaInFlight = {};

  String get _baseUrl {
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

  Map<String, String> _authHeaders(String? token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
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
    return 'Error $statusCode';
  }

  /// Lista los ítems de Ingredientes a productos (pendientes de compra) del hogar activo.
  Future<List<PendienteCompra>> getPendientes() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/pendientes');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => PendienteCompra.fromJson(e))
        .toList();
  }

  /// Envía a Ingredientes a productos los ingredientes faltantes de varias recetas (p. ej. del Planner).
  /// [recipeIds] IDs de recetas. [porcionesDeseadas] opcional map recetaId -> porciones.
  /// [recetaCantidades] opcional map recetaId -> veces (p. ej. repeticiones en la semana); se envía como receta_cantidades.
  Future<BulkEnviarResult> bulkEnviarAPendientes(
    List<int> recipeIds, {
    Map<int, int>? porcionesDeseadas,
    Map<int, int>? recetaCantidades,
    bool forzarReenvio = false,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final body = <String, dynamic>{
      'receta_ids': recipeIds,
    };
    if (porcionesDeseadas != null && porcionesDeseadas.isNotEmpty) {
      body['porciones_deseadas'] = porcionesDeseadas.map((k, v) => MapEntry(k.toString(), v));
    }
    if (recetaCantidades != null && recetaCantidades.isNotEmpty) {
      body['receta_cantidades'] = recetaCantidades.map((k, v) => MapEntry(k.toString(), v));
    }
    if (forzarReenvio) {
      body['forzar_reenvio'] = true;
    }
    final uri = Uri.parse('$_baseUrl/shopping/pendientes/bulk');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final provSug = decoded['proveedor_sugerido_id'];
    return BulkEnviarResult(
      message: decoded['message'] as String? ?? '',
      ingredientesAnadidos: (decoded['ingredientes_anadidos'] as num?)?.toInt() ?? 0,
      recetasProcesadas: (decoded['recetas_procesadas'] as List<dynamic>?)?.length ?? 0,
      reenvioDisponible: decoded['reenvio_disponible'] == true,
      proveedorSugeridoId: provSug is int ? provSug : (provSug is num ? provSug.toInt() : null),
    );
  }

  /// Mueve un pendiente de Ingredientes a productos a una lista de compra.
  /// [pendienteId] ID del PendienteCompra. Opcional: [listaDestinoId], [productoId], [cantidadCompra], [unidadMedidaId].
  Future<void> distribuirPendiente(
    int pendienteId, {
    int? listaDestinoId,
    int? productoId,
    double? cantidadCompra,
    int? unidadMedidaId,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final body = <String, dynamic>{'pendiente_id': pendienteId};
    if (listaDestinoId != null) body['lista_destino_id'] = listaDestinoId;
    if (productoId != null) body['producto_id'] = productoId;
    if (cantidadCompra != null) body['cantidad_compra'] = cantidadCompra;
    if (unidadMedidaId != null) body['unidad_medida_id'] = unidadMedidaId;
    final uri = Uri.parse('$_baseUrl/shopping/pendientes/distribuir');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Distribuye varios pendientes a una misma lista en una sola petición (más rápido que N llamadas a distribuirPendiente).
  Future<int> distribuirPendienteBulk({
    required int listaDestinoId,
    required List<int> pendienteIds,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    if (pendienteIds.isEmpty) {
      throw Exception('Indica al menos un pendiente.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/pendientes/distribuir-bulk');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'lista_destino_id': listaDestinoId,
        'pendiente_ids': pendienteIds,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final distribuidos = decoded['distribuidos'];
    return distribuidos is int ? distribuidos : pendienteIds.length;
  }

  /// Distribuye pendientes según preferencia de proveedor.
  Future<DistribucionPreferenciaResult> distribuirPendientesPorPreferencia({
    required int preferenciaProveedorId,
    required List<int> pendienteIds,
    String? fechaPrevista,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    if (pendienteIds.isEmpty) {
      throw Exception('Indica al menos un pendiente.');
    }
    final body = <String, dynamic>{
      'preferencia_proveedor_id': preferenciaProveedorId,
      'pendiente_ids': pendienteIds,
    };
    if (fechaPrevista != null && fechaPrevista.isNotEmpty) {
      body['fecha_prevista'] = fechaPrevista;
    }
    final uri = Uri.parse('$_baseUrl/shopping/pendientes/distribuir-preferencia');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final listaPrincipalId = decoded['lista_principal_id'];
    final listasPorProveedor = decoded['listas_por_proveedor'];
    return DistribucionPreferenciaResult(
      listaPrincipalId: listaPrincipalId is int ? listaPrincipalId : (listaPrincipalId is num ? listaPrincipalId.toInt() : null),
      listasPorProveedor: listasPorProveedor is Map<String, dynamic>
          ? listasPorProveedor.map((k, v) => MapEntry(int.parse(k.toString()), (v as num).toInt()))
          : const {},
    );
  }

  /// Listas de compra del hogar activo, con ítems. [archivada] true = solo archivadas, false = solo activas.
  Future<List<ListaCompraCabecera>> getListas({
    bool archivada = false,
    bool? pendienteProcesar,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final query = <String, String>{};
    if (archivada) query['archivada'] = '1';
    if (pendienteProcesar == true) query['pendiente_procesar'] = '1';
    final uri = Uri.parse('$_baseUrl/shopping/listas').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => ListaCompraCabecera.fromJson(e))
        .toList();
  }

  /// Obtiene una sola lista de compra por ID (con ítems). Más eficiente que getListas cuando solo se necesita una lista.
  Future<ListaCompraCabecera> getLista(int id) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$id');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode == 404) {
      throw Exception('Lista no encontrada.');
    }
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Respuesta inválida.');
    }
    return ListaCompraCabecera.fromJson(data);
  }

  /// Elimina una lista de compra. Solo permitido si está archivada.
  Future<void> eliminarLista(int listaId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$listaId');
    final response = await http.delete(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Archiva una lista de compra (solo si todos los ítems están procesados o no disponibles).
  Future<void> archivarLista(int listaId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$listaId/archivar');
    final response = await http.patch(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Marca la lista como "pendiente de procesar" (ya pasó por caja). La lista pasará a la pestaña Pendientes de procesar.
  Future<void> marcarPendienteProcesar(int listaId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$listaId/marcar-pendiente-procesar');
    final response = await http.patch(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Vuelve la lista a "listas activas" (quita pendiente de procesar). Útil cuando hay artículos pendientes.
  Future<void> reactivarLista(int listaId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$listaId/reactivar');
    final response = await http.patch(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Busca el ítem pendiente de la lista que coincide con el EAN (sin marcarlo).
  /// Busca un ítem de la lista por EAN (cualquier estado). Lanza si no hay ninguno (404) o hay otro error.
  Future<ListaCompraItem> buscarItemPorEan(int listaId, String ean) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$listaId/buscar-item-por-ean');
    final normalized = ean.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      throw Exception('El código EAN no puede estar vacío.');
    }
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'ean': normalized}),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return ListaCompraItem.fromJson(data);
  }

  /// Marca como "en el carrito" el primer ítem pendiente de la lista cuyo producto coincida con el EAN.
  /// Lanza si el código no corresponde a ningún producto pendiente (404) o hay otro error.
  Future<void> marcarPorEan(int listaId, String ean) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$listaId/marcar-por-ean');
    final normalized = ean.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      throw Exception('El código EAN no puede estar vacío.');
    }
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'ean': normalized}),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Busca un producto en el catálogo por EAN (no en la lista).
  /// Devuelve id, nombre y opcionalmente productoProveedorId cuando el EAN
  /// coincide con una entrada del catálogo de proveedores (para preseleccionar formato).
  Future<({int id, String nombre, int? productoProveedorId})> buscarProductoPorEan(String ean) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/buscar-producto-por-ean');
    final normalized = ean.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      throw Exception('El código EAN no puede estar vacío.');
    }
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'ean': normalized}),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final ppId = data['producto_proveedor_id'];
    return (
      id: data['id'] as int,
      nombre: data['nombre'] as String,
      productoProveedorId: ppId is int ? ppId : (ppId is num ? ppId.toInt() : null),
    );
  }

  /// Crea una nueva lista de compra para el hogar activo.
  Future<ListaCompraCabecera> crearLista(String titulo, {String? fechaPrevista}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas');
    final body = <String, dynamic>{'titulo': titulo};
    if (fechaPrevista != null) {
      body['fecha_prevista'] = fechaPrevista;
    }
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return ListaCompraCabecera.fromJson(data);
  }

  /// Actualiza la cabecera de una lista (título y/o fecha prevista).
  /// [clearFechaPrevista] true envía fecha_prevista: null para quitar la fecha.
  Future<ListaCompraCabecera> updateLista(int id, {String? titulo, String? fechaPrevista, bool clearFechaPrevista = false}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$id');
    final body = <String, dynamic>{};
    if (titulo != null) body['titulo'] = titulo;
    if (fechaPrevista != null) body['fecha_prevista'] = fechaPrevista;
    if (clearFechaPrevista) body['fecha_prevista'] = null;
    if (body.isEmpty) {
      throw Exception('Indica titulo o fecha_prevista.');
    }
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return ListaCompraCabecera.fromJson(data);
  }

  /// Lista proveedores con crear_lista_automatica para el selector "¿A qué supermercado vas?".
  Future<List<ProveedorItem>> getProveedores() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/proveedores');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => ProveedorItem(id: (e['id'] as num).toInt(), nombre: (e['nombre'] as String?) ?? ''))
        .toList();
  }

  /// Obtiene una lista de compra existente para el proveedor o la crea si el proveedor
  /// tiene "crear lista automáticamente" activado (ej. Mercadona). Si el proveedor no
  /// tiene el flag (ej. Carrefour), el backend responde 422 y no se crea lista.
  /// [fechaPrevista] opcional al crear lista nueva (formato YYYY-MM-DD).
  Future<ListaCompraCabecera> getOrCreateListaForProveedor(int proveedorId, {String? fechaPrevista}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final body = <String, dynamic>{'proveedor_id': proveedorId};
    if (fechaPrevista != null && fechaPrevista.isNotEmpty) body['fecha_prevista'] = fechaPrevista;
    final uri = Uri.parse('$_baseUrl/shopping/listas/obtener-o-crear-por-proveedor');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return ListaCompraCabecera.fromJson(data);
  }

  /// Actualiza el estado de un ítem (completado/pendiente/no_disponible) o asigna producto (para ítems solo ingrediente).
  Future<ListaCompraItem> updateListItem(
    int itemId, {
    bool? completado,
    String? estado,
    double? cantidad,
    int? unidadMedidaId,
    int? productoId,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final body = <String, dynamic>{};
    if (estado != null) body['estado'] = estado;
    if (completado != null) body['completado'] = completado;
    if (cantidad != null) body['cantidad'] = cantidad;
    if (unidadMedidaId != null) body['unidad_medida_id'] = unidadMedidaId;
    if (productoId != null) body['producto_id'] = productoId;
    if (body.isEmpty) {
      throw Exception('Indica completado, estado, cantidad, unidad_medida_id o producto_id.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/items/$itemId');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 422) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final provId = decoded['proveedor_id'];
            final provNombre = decoded['proveedor_nombre'] as String?;
            if (provId != null && provNombre != null && provNombre.isNotEmpty) {
              final id = provId is int ? provId : (provId is num ? provId.toInt() : null);
              if (id != null) {
                throw ProductoOtroSupermercadoException(id, provNombre);
              }
            }
          }
        } catch (e) {
          if (e is ProductoOtroSupermercadoException) rethrow;
        }
      }
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta sin data.');
    return ListaCompraItem.fromJson(data);
  }

  /// Crea un producto propuesto desde la lista (cuando no hay productos para el ingrediente)
  /// y asigna ese producto al ítem. Devuelve el ítem actualizado.
  Future<ListaCompraItem> proponerProducto(
    int itemId, {
    required String nombre,
    required String ean,
    int? proveedorId,
    double? cantidadUnidad,
    int? unidadMedidaId,
    double? precio,
    String? formatoProveedor,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final body = <String, dynamic>{
      'nombre': nombre,
      'ean': ean,
    };
    if (proveedorId != null && proveedorId > 0) body['proveedor_id'] = proveedorId;
    if (cantidadUnidad != null) body['cantidad_unidad'] = cantidadUnidad;
    if (unidadMedidaId != null && unidadMedidaId > 0) body['unidad_medida_id'] = unidadMedidaId;
    if (precio != null) body['precio'] = precio;
    if (formatoProveedor != null && formatoProveedor.isNotEmpty) body['formato_proveedor'] = formatoProveedor;
    final uri = Uri.parse('$_baseUrl/shopping/listas/items/$itemId/proponer-producto');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta sin data.');
    return ListaCompraItem.fromJson(data);
  }

  /// Elimina un ítem de la lista de compra (lo quita de la lista).
  Future<void> deleteListItem(int itemId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/items/$itemId');
    final response = await http.delete(uri, headers: _authHeaders(token));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Finaliza la compra: mueve ítems completados al inventario.
  /// Cada línea debe tener lista_compra_item_id, contenedor_id y cantidad.
  Future<ProcesarCompraResult> procesarCompra(List<ProcesarCompraLinea> lineas) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    if (lineas.isEmpty) {
      throw Exception('No hay líneas para procesar.');
    }
    final body = <String, dynamic>{
      'lineas': lineas
          .map((l) => {
                'lista_compra_item_id': l.listaCompraItemId,
                'contenedor_id': l.contenedorId,
                'cantidad': l.cantidad,
                if (l.unidadMedidaId != null) 'unidad_medida_id': l.unidadMedidaId,
                if (l.fechaCaducidad != null) 'fecha_caducidad': l.fechaCaducidad,
              })
          .toList(),
    };
    final uri = Uri.parse('$_baseUrl/shopping/procesar-compra');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ProcesarCompraResult(
      message: (decoded['message'] as String?) ?? '',
      procesados: (decoded['procesados'] as num?)?.toInt() ?? 0,
    );
  }

  /// Obtiene productos para selector (Crear ítem). Con [q] busca por nombre/marca; [page] para paginación.
  Future<List<ProductoSimple>> getProductos({String? q, int perPage = 100, int page = 1}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final queryParams = <String, String>{
      if (perPage > 0) 'per_page': perPage.toString(),
      if (page > 1) 'page': page.toString(),
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    final uri = Uri.parse('$_baseUrl/productos').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => ProductoSimple.fromJson(e))
        .toList();
  }

  /// Formatos (pack/unidad) del catálogo de proveedores para un producto.
  Future<List<FormatoProveedor>> getPreciosProveedores(int productoId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/productos/$productoId/precios-proveedores');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => FormatoProveedor.fromJson(e))
        .toList();
  }

  /// Añade un producto como ítem a una lista de compra.
  /// [productoProveedorId] opcional: id del formato (pack/unidad) del catálogo.
  Future<ListaCompraItem> addItemToLista(
    int listaId,
    int productoId,
    double cantidad, {
    int? unidadMedidaId,
    int? productoProveedorId,
    bool completado = false,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    final uri = Uri.parse('$_baseUrl/shopping/listas/$listaId/items');
    final body = <String, dynamic>{
      'producto_id': productoId,
      'cantidad': cantidad,
      if (unidadMedidaId != null) 'unidad_medida_id': unidadMedidaId,
      if (productoProveedorId != null) 'producto_proveedor_id': productoProveedorId,
      'completado': completado,
    };
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta sin data.');
    return ListaCompraItem.fromJson(data);
  }

  /// Obtiene productos filtrados por ingrediente_id. Si [proveedorId] no es null,
  /// solo devuelve productos de ese proveedor (ej. Mercadona) para listas de un super concreto.
  Future<List<ProductoSimple>> getProductosPorIngrediente(
    int ingredienteId, {
    int? proveedorId,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    var uri = Uri.parse('$_baseUrl/productos?ingrediente_id=$ingredienteId');
    if (proveedorId != null && proveedorId > 0) {
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'proveedor_id': proveedorId.toString(),
      });
    }
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => ProductoSimple.fromJson(e))
        .toList();
  }

  /// Obtiene unidades de medida. Si [ingredienteId] está definido, solo devuelve
  /// las unidades de los tipos configurados para ese ingrediente (backend).
  /// Resultados se cachean en memoria y se deduplican peticiones en curso.
  Future<List<UnidadMedidaCompleta>> getUnidadesMedida({int? ingredienteId}) async {
    final key = ingredienteId != null && ingredienteId > 0 ? ingredienteId.toString() : 'all';
    final cached = _unidadesMedidaCache[key];
    if (cached != null) return cached;
    final inFlight = _unidadesMedidaInFlight[key];
    if (inFlight != null) return inFlight;
    final future = _fetchUnidadesMedida(ingredienteId: ingredienteId);
    _unidadesMedidaInFlight[key] = future;
    try {
      final list = await future;
      _unidadesMedidaCache[key] = list;
      return list;
    } finally {
      _unidadesMedidaInFlight.remove(key);
    }
  }

  Future<List<UnidadMedidaCompleta>> _fetchUnidadesMedida({int? ingredienteId}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }
    var uri = Uri.parse('$_baseUrl/unidades-medida');
    if (ingredienteId != null && ingredienteId > 0) {
      uri = uri.replace(queryParameters: {'ingrediente_id': ingredienteId.toString()});
    }
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => UnidadMedidaCompleta.fromJson(e))
        .toList();
  }

  /// Invalida la caché de unidades de medida (p. ej. al cerrar sesión).
  void clearUnidadesMedidaCache() {
    _unidadesMedidaCache.clear();
    _unidadesMedidaInFlight.clear();
  }
}

/// Línea para procesar compra: ítem + contenedor + cantidad.
class ProcesarCompraLinea {
  final int listaCompraItemId;
  final int contenedorId;
  final double cantidad;
  final int? unidadMedidaId;
  final String? fechaCaducidad;

  const ProcesarCompraLinea({
    required this.listaCompraItemId,
    required this.contenedorId,
    required this.cantidad,
    this.unidadMedidaId,
    this.fechaCaducidad,
  });
}

class ProcesarCompraResult {
  final String message;
  final int procesados;

  const ProcesarCompraResult({required this.message, required this.procesados});
}

class BulkEnviarResult {
  final String message;
  final int ingredientesAnadidos;
  final int recetasProcesadas;
  final bool reenvioDisponible;
  final int? proveedorSugeridoId;

  const BulkEnviarResult({
    required this.message,
    required this.ingredientesAnadidos,
    required this.recetasProcesadas,
    this.reenvioDisponible = false,
    this.proveedorSugeridoId,
  });
}

class DistribucionPreferenciaResult {
  final int? listaPrincipalId;
  final Map<int, int> listasPorProveedor;

  const DistribucionPreferenciaResult({
    required this.listaPrincipalId,
    required this.listasPorProveedor,
  });
}

/// Proveedor para selector "¿A qué supermercado vas?" (crear_lista_automatica = true).
class ProveedorItem {
  final int id;
  final String nombre;

  const ProveedorItem({required this.id, required this.nombre});
}

/// Formato (pack/unidad) del catálogo de proveedores para un producto.
/// [unidadMedidaTipo]: "volumen", "peso" o "unidad" para filtrar unidades en el desplegable.
class FormatoProveedor {
  final int id;
  final String? formato;
  final String? proveedorNombre;
  final double? precio;
  final int? unidadMedidaId;
  final String? unidadMedidaTipo;

  const FormatoProveedor({
    required this.id,
    this.formato,
    this.proveedorNombre,
    this.precio,
    this.unidadMedidaId,
    this.unidadMedidaTipo,
  });

  factory FormatoProveedor.fromJson(Map<String, dynamic> json) {
    final p = json['precio'];
    final umId = json['unidad_medida_id'];
    return FormatoProveedor(
      id: json['id'] as int,
      formato: json['formato'] as String?,
      proveedorNombre: json['proveedor_nombre'] as String?,
      precio: p is num ? p.toDouble() : (p is String ? double.tryParse(p) : null),
      unidadMedidaId: umId is int ? umId : (umId is num ? umId.toInt() : null),
      unidadMedidaTipo: json['unidad_medida_tipo'] as String?,
    );
  }

  String get label => (formato?.trim().isNotEmpty == true) ? formato! : 'Sin formato';
}

/// Producto simplificado para selector.
class ProductoSimple {
  final int id;
  final String nombre;
  final String? marca;
  final String? formato;
  final int ingredienteId;
  final int? unidadMedidaId;
  /// Abreviatura de la unidad de medida (p. ej. "kg", "l") cuando el API la envía.
  final String? unidadMedidaAbreviatura;
  /// Proveedor principal del producto (ej. Mercadona). Null si no tiene.
  final int? proveedorId;
  /// Si true, al elegir este producto se puede obtener/crear automáticamente una lista para el proveedor.
  final bool crearListaAutomatica;

  const ProductoSimple({
    required this.id,
    required this.nombre,
    this.marca,
    this.formato,
    required this.ingredienteId,
    this.unidadMedidaId,
    this.unidadMedidaAbreviatura,
    this.proveedorId,
    this.crearListaAutomatica = false,
  });

  factory ProductoSimple.fromJson(Map<String, dynamic> json) {
    final um = json['unidad_medida'];
    String? abrev;
    if (um is Map<String, dynamic>) {
      abrev = um['abreviatura'] as String?;
    }
    final provId = json['proveedor_id'];
    return ProductoSimple(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      marca: json['marca'] as String?,
      formato: json['formato'] as String?,
      ingredienteId: json['ingrediente_id'] as int,
      unidadMedidaId: json['unidad_medida_id'] as int?,
      unidadMedidaAbreviatura: abrev,
      proveedorId: provId is int ? provId : (provId is num ? provId.toInt() : null),
      crearListaAutomatica: json['crear_lista_automatica'] == true,
    );
  }

  String get displayNombre {
    final partes = [nombre];
    if (marca?.isNotEmpty == true) partes.add(marca!);
    if (formato?.isNotEmpty == true) partes.add(formato!);
    return partes.join(' - ');
  }
}

/// Unidad de medida completa con tipo y factor de conversión.
class UnidadMedidaCompleta {
  final int id;
  final String nombre;
  final String? abreviatura;
  final String tipo;
  final double factorConversion;

  const UnidadMedidaCompleta({
    required this.id,
    required this.nombre,
    this.abreviatura,
    required this.tipo,
    required this.factorConversion,
  });

  factory UnidadMedidaCompleta.fromJson(Map<String, dynamic> json) {
    final fc = json['factor_conversion'];
    final factorConversion = fc is num
        ? fc.toDouble()
        : (fc is String ? double.tryParse(fc.replaceAll(',', '.')) : null) ?? 1.0;
    return UnidadMedidaCompleta(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      abreviatura: json['abreviatura'] as String?,
      tipo: (json['tipo'] as String?) ?? 'masa',
      factorConversion: factorConversion,
    );
  }
}
