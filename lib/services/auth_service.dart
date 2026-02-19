import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String get _baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return '${Uri.base.scheme}://$host:8000/api';
    }
    return 'http://192.168.1.39:8000/api';
  }
  static final ValueNotifier<AuthUser?> userNotifier = ValueNotifier<AuthUser?>(null);

  Future<String> register(String name, String email, String password) async {
    final uri = Uri.parse('$_baseUrl/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = payload['token'] as String?;
    final user = payload['user'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty) {
      throw Exception('No token returned by server.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (user != null) {
      await _storeUserSnapshot(prefs, user);
    }

    return token;
  }

  Future<String> login(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = payload['token'] as String?;
    final user = payload['user'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty) {
      throw Exception('No token returned by server.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (user != null) {
      await _storeUserSnapshot(prefs, user);
    }

    return token;
  }

  Future<bool> fetchHasHogar() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      return false;
    }

    final uri = Uri.parse('$_baseUrl/me');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      await prefs.remove('auth_token');
      return false;
    }

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final hasHogar = data['has_hogar'];
      if (hasHogar is bool) {
        return hasHogar;
      }
    }

    return false;
  }

  Future<AuthUser> fetchUser({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesion no iniciada.');
    }
    if (!forceRefresh) {
      final cached = _readUserSnapshot(prefs);
      if (cached != null) {
        userNotifier.value = cached;
        return cached;
      }
    }

    final uri = Uri.parse('$_baseUrl/me');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final user = data['user'];
      final hogarActivo = data['hogar_activo'];
      if (hogarActivo is Map<String, dynamic>) {
        final hogarNombre = hogarActivo['nombre'] as String?;
        if (hogarNombre != null && hogarNombre.isNotEmpty) {
          await prefs.setString('hogar_nombre', hogarNombre);
        }
      }
      if (user is Map<String, dynamic>) {
        await _storeUserSnapshot(prefs, user);
        final parsed = _userFromMap(user, prefs);
        userNotifier.value = parsed;
        return parsed;
      }
    }

    const fallback = AuthUser(name: 'Usuario', email: '');
    userNotifier.value = fallback;
    return fallback;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      return;
    }

    final uri = Uri.parse('$_baseUrl/logout');
    await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    await prefs.remove('auth_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('user_avatar_url');
    userNotifier.value = null;
  }

  /// Sube la imagen de perfil al endpoint POST /api/me/avatar (multipart).
  /// Actualiza prefs y userNotifier con la nueva avatar_url para que Drawer y equipo se refresquen.
  Future<void> uploadAvatar(Uint8List bytes, String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }

    final uri = Uri.parse('$_baseUrl/me/avatar');
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
    final userMap = data?['user'] as Map<String, dynamic>?;
    if (userMap == null) {
      throw Exception('No se recibió el usuario.');
    }

    await _storeUserSnapshot(prefs, userMap);
    final current = userNotifier.value;
    final hogarNombre = current?.hogarNombre ?? prefs.getString('hogar_nombre');
    userNotifier.value = AuthUser(
      id: (userMap['id'] as num?)?.toInt() ?? current?.id,
      name: (userMap['name'] as String?) ?? current?.name ?? 'Usuario',
      email: (userMap['email'] as String?) ?? current?.email ?? '',
      role: (userMap['tipo_suscripcion'] ?? userMap['role']) as String?,
      hogarNombre: hogarNombre,
      avatarUrl: userMap['avatar_url'] as String?,
      birthDate: current?.birthDate,
      intoleranciaIds: current?.intoleranciaIds ?? [],
      notas: current?.notas,
    );
  }

  Future<void> updateHogarActivo(String? nombre) async {
    final prefs = await SharedPreferences.getInstance();
    if (nombre == null || nombre.isEmpty) {
      await prefs.remove('hogar_nombre');
      final current = userNotifier.value;
      if (current != null) {
        userNotifier.value = AuthUser(
          id: current.id,
          name: current.name,
          email: current.email,
          role: current.role,
          hogarNombre: null,
          avatarUrl: current.avatarUrl,
          birthDate: current.birthDate,
          intoleranciaIds: current.intoleranciaIds,
          notas: current.notas,
        );
      }
      return;
    }
    await prefs.setString('hogar_nombre', nombre);
    final current = userNotifier.value;
    if (current != null) {
      userNotifier.value = AuthUser(
        id: current.id,
        name: current.name,
        email: current.email,
        role: current.role,
        hogarNombre: nombre,
        avatarUrl: current.avatarUrl,
        birthDate: current.birthDate,
        intoleranciaIds: current.intoleranciaIds,
        notas: current.notas,
      );
    }
  }

  String _extractError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
        final errors = decoded['errors'];
        if (errors is Map<String, dynamic>) {
          final first = errors.values.cast<dynamic>().first;
          if (first is List && first.isNotEmpty) {
            return first.first.toString();
          }
        }
      }
    } catch (_) {}

    return 'Request failed ($statusCode).';
  }

  Future<void> _storeUserSnapshot(
    SharedPreferences prefs,
    Map<String, dynamic> user,
  ) async {
    final name = user['name'] as String?;
    final email = user['email'] as String?;
    final role = (user['tipo_suscripcion'] ?? user['role']) as String?;
    final avatarUrl = user['avatar_url'] as String?;
    final birthDate = user['birth_date'] as String?;
    final intolerancias = user['intolerancias'] as List<dynamic>?;
    final notas = user['notas'] as String?;
    final id = user['id'];
    if (name != null) {
      await prefs.setString('user_name', name);
    }
    if (id is num) {
      await prefs.setString('user_id', id.toInt().toString());
    }
    if (email != null) {
      await prefs.setString('user_email', email);
    }
    if (role != null) {
      await prefs.setString('user_role', role);
    }
    if (avatarUrl != null) {
      await prefs.setString('user_avatar_url', avatarUrl);
    } else {
      await prefs.remove('user_avatar_url');
    }
    if (birthDate != null) {
      await prefs.setString('user_birth_date', birthDate);
    } else {
      await prefs.remove('user_birth_date');
    }
    if (intolerancias != null && intolerancias.isNotEmpty) {
      final ids = intolerancias
          .whereType<Map<String, dynamic>>()
          .map((e) => (e['id'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      await prefs.setStringList('user_intolerancia_ids', ids.map((e) => e.toString()).toList());
    } else {
      await prefs.remove('user_intolerancia_ids');
    }
    if (notas != null) {
      await prefs.setString('user_notas', notas);
    } else {
      await prefs.remove('user_notas');
    }
  }

  AuthUser? _readUserSnapshot(SharedPreferences prefs) {
    final name = prefs.getString('user_name');
    final email = prefs.getString('user_email');
    final role = prefs.getString('user_role');
    final hogarNombre = prefs.getString('hogar_nombre');
    final avatarUrl = prefs.getString('user_avatar_url');
    final birthDateStr = prefs.getString('user_birth_date');
    final intoleranciaIdsStr = prefs.getStringList('user_intolerancia_ids');
    final notas = prefs.getString('user_notas');
    final idStr = prefs.getString('user_id');
    if (name == null && email == null && role == null) {
      return null;
    }
    DateTime? birthDate;
    if (birthDateStr != null && birthDateStr.isNotEmpty) {
      birthDate = DateTime.tryParse(birthDateStr);
    }
    final intoleranciaIds = intoleranciaIdsStr
        ?.map((e) => int.tryParse(e))
        .whereType<int>()
        .toList() ?? [];
    final id = idStr != null ? int.tryParse(idStr) : null;
    return AuthUser(
      id: id,
      name: name ?? 'Usuario de prueba',
      email: email ?? '',
      role: role,
      hogarNombre: hogarNombre,
      avatarUrl: avatarUrl,
      birthDate: birthDate,
      intoleranciaIds: intoleranciaIds,
      notas: notas,
    );
  }

  AuthUser _userFromMap(Map<String, dynamic> user, SharedPreferences prefs) {
    final hogarNombre = prefs.getString('hogar_nombre');
    final avatarUrl = user['avatar_url'] as String?;
    final birthDateStr = user['birth_date'] as String?;
    final intolerancias = user['intolerancias'] as List<dynamic>?;
    if (avatarUrl != null) {
      prefs.setString('user_avatar_url', avatarUrl);
    } else {
      prefs.remove('user_avatar_url');
    }
    DateTime? birthDate;
    if (birthDateStr != null && birthDateStr.isNotEmpty) {
      birthDate = DateTime.tryParse(birthDateStr);
    }
    final intoleranciaIds = intolerancias
        ?.whereType<Map<String, dynamic>>()
        .map((e) => (e['id'] as num?)?.toInt())
        .whereType<int>()
        .toList() ?? [];
    final notas = user['notas'] as String?;
    final id = (user['id'] as num?)?.toInt();
    return AuthUser(
      id: id,
      name: (user['name'] as String?) ?? 'Usuario de prueba',
      email: (user['email'] as String?) ?? '',
      role: (user['tipo_suscripcion'] ?? user['role']) as String?,
      hogarNombre: hogarNombre,
      avatarUrl: avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null,
      birthDate: birthDate,
      intoleranciaIds: intoleranciaIds,
      notas: notas,
    );
  }

  /// Actualiza el perfil del usuario (name, birth_date, notas, intolerancias) vía PATCH /me y actualiza el estado global.
  Future<void> updateProfile({
    required String name,
    DateTime? birthDate,
    String? notas,
    required List<int> intoleranciaIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }

    final uri = Uri.parse('$_baseUrl/me');
    final body = <String, dynamic>{
      'name': name,
      'intolerancias': intoleranciaIds,
    };
    if (birthDate != null) {
      body['birth_date'] = birthDate.toIso8601String().split('T').first;
    }
    if (notas != null) {
      body['notas'] = notas;
    }
    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final userMap = data?['user'] as Map<String, dynamic>?;
    if (userMap != null) {
      await _storeUserSnapshot(prefs, userMap);
      final current = userNotifier.value;
      final hogarNombre = current?.hogarNombre ?? prefs.getString('hogar_nombre');
      final avatarUrl = userMap['avatar_url'] as String?;
      final birthDateStr = userMap['birth_date'] as String?;
      final intolerancias = userMap['intolerancias'] as List<dynamic>?;
      final notas = userMap['notas'] as String?;
      DateTime? parsedBirthDate;
      if (birthDateStr != null && birthDateStr.isNotEmpty) {
        parsedBirthDate = DateTime.tryParse(birthDateStr);
      }
      final ids = intolerancias
          ?.whereType<Map<String, dynamic>>()
          .map((e) => (e['id'] as num?)?.toInt())
          .whereType<int>()
          .toList() ?? [];
      userNotifier.value = AuthUser(
        id: (userMap['id'] as num?)?.toInt() ?? current?.id,
        name: (userMap['name'] as String?) ?? current?.name ?? 'Usuario',
        email: (userMap['email'] as String?) ?? current?.email ?? '',
        role: (userMap['tipo_suscripcion'] ?? userMap['role']) as String? ?? current?.role,
        hogarNombre: hogarNombre,
        avatarUrl: avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null,
        birthDate: parsedBirthDate,
        intoleranciaIds: ids,
        notas: notas ?? current?.notas,
      );
    }
  }

  /// Cambia la contraseña del usuario (PATCH /me/password). Requiere contraseña actual.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no iniciada.');
    }

    final uri = Uri.parse('$_baseUrl/me/password');
    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      }),
    );

    if (response.statusCode == 422) {
      final decoded = jsonDecode(response.body);
      final message = decoded is Map ? (decoded['message'] as String?) : null;
      throw Exception(message ?? 'Contraseña actual incorrecta.');
    }
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body, response.statusCode));
    }
  }
}

class AuthUser {
  final int? id;
  final String name;
  final String email;
  final String? role;
  final String? hogarNombre;
  final String? avatarUrl;
  final DateTime? birthDate;
  final List<int> intoleranciaIds;
  final String? notas;

  const AuthUser({
    this.id,
    required this.name,
    required this.email,
    this.role,
    this.hogarNombre,
    this.avatarUrl,
    this.birthDate,
    this.intoleranciaIds = const [],
    this.notas,
  });
}
