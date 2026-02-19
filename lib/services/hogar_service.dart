import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_data.dart';
import '../models/hogar.dart';
import 'auth_service.dart';
import '../models/hogar_equipo.dart';
import '../models/intolerancia.dart';

class HogarService {
  static String get _baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return '${Uri.base.scheme}://$host:8000/api';
    }
    return 'http://192.168.1.39:8000/api';
  }

  Future<HogaresResult> fetchHogares() async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares');
    final response = await http.get(
      uri,
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    final hogares = <Hogar>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          hogares.add(Hogar.fromJson(item));
        }
      }
    }
    final hogarActivoId = (decoded['hogar_activo_id'] as num?)?.toInt();
    final puedeCambiarHogarActivo = decoded['puede_cambiar_hogar_activo'] as bool? ?? true;

    return HogaresResult(
      hogares: hogares,
      hogarActivoId: hogarActivoId,
      puedeCambiarHogarActivo: puedeCambiarHogarActivo,
    );
  }

  Future<int?> crearHogar({
    required String nombre,
    String? direccion,
    String? telefono,
    bool? esPrincipal,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
        if (esPrincipal != null) 'es_principal': esPrincipal,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final hogarId = _extractHogarId(response.body);
    await _storeHogarId(hogarId, nombre: _extractHogarNombre(response.body));
    return hogarId;
  }

  Future<void> unirseAHogar(String codigo) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/join');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'codigo': codigo}),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final hogarId = _extractHogarId(response.body);
    final nombre = _extractHogarNombre(response.body);
    await _storeHogarId(hogarId, nombre: nombre);
  }

  Future<int?> createHogar(String nombre) => crearHogar(nombre: nombre);

  Future<void> joinByCode(String codigo) => unirseAHogar(codigo);

  Future<void> setHogarActivo(int hogarId) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/active');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'hogar_id': hogarId}),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final nombre = _extractHogarNombre(response.body);
    await _storeHogarId(hogarId, nombre: nombre);
    hogarActivoIdNotifier.value = hogarId;
    await AuthService().fetchUser(forceRefresh: true);
  }

  /// Marca un hogar como principal (solo actualiza es_principal en el backend).
  /// No cambia el hogar activo. Tras el éxito notifica [hogaresDataChangedNotifier]
  /// para que el drawer y las pantallas de hogares refresquen la lista.
  Future<void> setHogarPrincipal(int hogarId) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/principal');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'hogar_id': hogarId}),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    // No actualizar hogar activo (SharedPreferences): principal y activo están desacoplados.
    hogaresDataChangedNotifier.value = hogaresDataChangedNotifier.value + 1;
  }

  Future<void> updateHogar({
    required int hogarId,
    required String nombre,
    String? direccion,
    String? telefono,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<void> deleteHogar(int hogarId) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId');
    final response = await http.delete(
      uri,
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<int?> getHogarIdActual() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('hogar_id_actual');
  }

  /// Limpia el hogar activo guardado (p. ej. tras 403 al acceder al equipo).
  Future<void> clearHogarActivo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hogar_id_actual');
    await prefs.remove('hogar_nombre');
  }

  Future<HogarEquipo> fetchEquipo(int hogarId) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/equipo');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return HogarEquipo.fromJson(data);
  }

  Future<String> generarInvitacion(int hogarId) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/invitacion');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'hogar_id': hogarId}),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    final codigo = data['codigo'] as String?;
    if (codigo == null || codigo.isEmpty) {
      throw Exception('No se pudo generar el código.');
    }
    return codigo;
  }

  Future<List<Intolerancia>> fetchIntolerancias() async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/intolerancias');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => Intolerancia.fromJson(item))
        .toList();
  }

  Future<void> addMiembroSinCuenta({
    required int hogarId,
    required String name,
    String? birthDate,
    List<int>? intoleranciasIds,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/miembro-sin-cuenta');
    final body = <String, dynamic>{
      'hogar_id': hogarId,
      'name': name,
      'intolerancias': intoleranciasIds ?? [],
    };
    if (birthDate != null && birthDate.isNotEmpty) body['birth_date'] = birthDate;
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// GET /hogares/{id}/invitaciones: lista códigos activos y límites del plan.
  Future<InvitacionesData> fetchInvitaciones(int hogarId) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/invitaciones');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return InvitacionesData.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  /// DELETE /hogares/{id}/invitaciones/{invitacionId}
  Future<void> eliminarInvitacion({
    required int hogarId,
    required int invitacionId,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/invitaciones/$invitacionId');
    final response = await http.delete(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<void> updateIntolerancias({
    required int hogarId,
    required int memberId,
    required List<int> intoleranciasIds,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/miembros/$memberId/intolerancias');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'intolerancias': intoleranciasIds}),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<void> expulsarMiembro({
    required int hogarId,
    required int userId,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/miembros/$userId');
    final response = await http.delete(
      uri,
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  Future<void> updateNotasMiembro({
    required int hogarId,
    required int userId,
    String? notas,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/miembros/$userId/notas');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'notas': notas}),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Actualiza perfil de miembro ficticio (solo titular, solo sin cuenta). name y edad.
  Future<void> updatePerfilMiembro({
    required int hogarId,
    required int userId,
    String? name,
    int? edad,
    String? birthDate,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/miembros/$userId/perfil');
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (edad != null) body['edad'] = edad;
    if (birthDate != null) body['birth_date'] = birthDate;
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// GET /me/dependientes: tutor + dependientes (tutor_id == usuario actual).
  Future<FamilyData> fetchMisDependientes() async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/me/dependientes');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return FamilyData.fromJson(decoded);
  }

  /// POST /me/dependientes: crea dependiente (name, birth_date; tutor_id = usuario actual).
  Future<HogarMember> crearDependiente({
    required String name,
    String? birthDate,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/me/dependientes');
    final body = <String, dynamic>{'name': name};
    if (birthDate != null && birthDate.isNotEmpty) body['birth_date'] = birthDate;
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return HogarMember.fromFamilyJson(data);
  }

  /// DELETE /me/dependientes/{id}: borrado definitivo (solo dependientes del tutor, sin email).
  Future<void> eliminarDependiente(int id) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/me/dependientes/$id');
    final response = await http.delete(uri, headers: _authHeaders(token));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// POST /hogares/{hogarId}/miembros/vincular: añade usuario (tutor o dependiente) al hogar.
  Future<void> vincularDependienteAHogar({
    required int hogarId,
    required int userId,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/miembros/vincular');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'user_id': userId}),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }

  /// Sube avatar para miembro ficticio (solo titular).
  Future<String> uploadAvatarMiembro({
    required int hogarId,
    required int userId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/hogares/$hogarId/miembros/$userId/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'avatar',
      bytes,
      filename: filename.isNotEmpty ? filename : 'avatar.jpg',
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final avatarUrl = data?['avatar_url'] as String?;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      throw Exception('No se recibió la URL del avatar.');
    }
    return avatarUrl;
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

  int? _extractHogarId(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          final id = data['id'];
          if (id is num) {
            return id.toInt();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _storeHogarId(int? hogarId, {String? nombre}) async {
    if (hogarId == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hogar_id_actual', hogarId);
    if (nombre != null && nombre.isNotEmpty) {
      await prefs.setString('hogar_nombre', nombre);
    }
  }

  String? _extractHogarNombre(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final name = decoded['hogar_activo_nombre'];
        if (name is String && name.isNotEmpty) {
          return name;
        }
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          final n = data['nombre'];
          if (n is String && n.isNotEmpty) {
            return n;
          }
        }
      }
    } catch (_) {}
    return null;
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

class HogaresResult {
  final List<Hogar> hogares;
  final int? hogarActivoId;
  final bool puedeCambiarHogarActivo;

  const HogaresResult({
    required this.hogares,
    required this.hogarActivoId,
    this.puedeCambiarHogarActivo = true,
  });
}

/// Notificador de cambio de hogar activo. Las pantallas que dependen del hogar pueden
/// escucharlo para recargar datos (equipo, despensa, semáforos).
final ValueNotifier<int?> hogarActivoIdNotifier = ValueNotifier<int?>(null);

/// Notificador de cambios en la lista de hogares (p. ej. al cambiar el principal).
/// El drawer y las pantallas "Mis Casas" / "Mis Hogares" pueden escucharlo para refrescar
/// la lista y mostrar de nuevo la estrella en el hogar principal.
final ValueNotifier<int> hogaresDataChangedNotifier = ValueNotifier<int>(0);

class InvitacionItem {
  final int id;
  final String codigo;
  final String? fechaExpiracion;

  const InvitacionItem({
    required this.id,
    required this.codigo,
    this.fechaExpiracion,
  });

  factory InvitacionItem.fromJson(Map<String, dynamic> json) {
    return InvitacionItem(
      id: (json['id'] as num).toInt(),
      codigo: json['codigo'] as String? ?? '',
      fechaExpiracion: json['fecha_expiracion'] as String?,
    );
  }
}

class InvitacionesData {
  final List<InvitacionItem> invitaciones;
  final int invitacionesActivasCount;
  final int miembrosCount;
  final int? limiteMiembros;
  final String plan;

  const InvitacionesData({
    required this.invitaciones,
    required this.invitacionesActivasCount,
    required this.miembrosCount,
    this.limiteMiembros,
    required this.plan,
  });

  factory InvitacionesData.fromJson(Map<String, dynamic> json) {
    final list = json['invitaciones'] as List<dynamic>? ?? [];
    return InvitacionesData(
      invitaciones: list
          .whereType<Map<String, dynamic>>()
          .map((e) => InvitacionItem.fromJson(e))
          .toList(),
      invitacionesActivasCount: (json['invitaciones_activas_count'] as num?)?.toInt() ?? 0,
      miembrosCount: (json['miembros_count'] as num?)?.toInt() ?? 0,
      limiteMiembros: json['limite_miembros'] is num
          ? (json['limite_miembros'] as num).toInt()
          : null,
      plan: json['plan'] as String? ?? 'gratis',
    );
  }

  /// Texto para "Códigos usados: X / Máximo: Y" (Y = Ilimitado si null).
  String get textoContador {
    final usado = miembrosCount + invitacionesActivasCount;
    if (limiteMiembros == null) {
      return 'Miembros + códigos activos: $usado / Ilimitado';
    }
    return 'Miembros + códigos activos: $usado / $limiteMiembros';
  }
}
