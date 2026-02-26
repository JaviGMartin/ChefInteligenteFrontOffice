import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Client ID de la aplicación web de Google (requerido para Flutter Web).
  static const String _googleWebClientId =
      '1089306067247-bevracoguobbhogtbc002e5n7o1jvupf.apps.googleusercontent.com';

  /// Inicia sesión con Google: obtiene id_token o access_token del plugin, envía a POST /api/auth/google y guarda token/usuario.
  /// En web el plugin a veces solo devuelve access_token; el backend acepta ambos.
  Future<String> loginWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: kIsWeb ? _googleWebClientId : null,
    );
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw Exception('Inicio de sesión con Google cancelado.');
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;

    if ((idToken == null || idToken.isEmpty) && (accessToken == null || accessToken.isEmpty)) {
      throw Exception('No se pudo obtener el token de Google.');
    }

    final body = <String, String>{};
    if (idToken != null && idToken.isNotEmpty) {
      body['id_token'] = idToken;
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      body['access_token'] = accessToken;
    }

    final uri = Uri.parse('$_baseUrl/auth/google');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
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
    final nutrition = <String, dynamic>{};
    for (final k in ['peso_kg', 'altura_cm', 'peso_habitual_kg', 'circunferencia_cintura_cm', 'circunferencia_cadera_cm', 'sexo', 'nivel_actividad', 'objetivo_dietetico', 'condiciones_medicas', 'medicacion_actual', 'embarazo_lactancia', 'imc', 'icc', 'tmb_kcal', 'get_energetico_kcal']) {
      if (user[k] != null) nutrition[k] = user[k];
    }
    if (nutrition.isNotEmpty) {
      await prefs.setString('user_nutrition', jsonEncode(nutrition));
    } else {
      await prefs.remove('user_nutrition');
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
    final nutritionStr = prefs.getString('user_nutrition');
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
    Map<String, dynamic>? nutrition;
    if (nutritionStr != null && nutritionStr.isNotEmpty) {
      try {
        nutrition = jsonDecode(nutritionStr) as Map<String, dynamic>?;
      } catch (_) {}
    }
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
      pesoKg: nutrition != null ? _toDouble(nutrition['peso_kg']) : null,
      alturaCm: nutrition != null ? _toDouble(nutrition['altura_cm']) : null,
      pesoHabitualKg: nutrition != null ? _toDouble(nutrition['peso_habitual_kg']) : null,
      circunferenciaCinturaCm: nutrition != null ? _toDouble(nutrition['circunferencia_cintura_cm']) : null,
      circunferenciaCaderaCm: nutrition != null ? _toDouble(nutrition['circunferencia_cadera_cm']) : null,
      sexo: nutrition?['sexo'] as String?,
      nivelActividad: nutrition?['nivel_actividad'] as String?,
      objetivoDietetico: nutrition?['objetivo_dietetico'] as String?,
      condicionesMedicas: nutrition?['condiciones_medicas'] as String?,
      medicacionActual: nutrition?['medicacion_actual'] as String?,
      embarazoLactancia: nutrition?['embarazo_lactancia'] as String?,
      imc: nutrition != null ? _toDouble(nutrition['imc']) : null,
      icc: nutrition != null ? _toDouble(nutrition['icc']) : null,
      tmbKcal: nutrition != null ? _toDouble(nutrition['tmb_kcal']) : null,
      getEnergeticoKcal: nutrition != null ? _toDouble(nutrition['get_energetico_kcal']) : null,
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
    final pesoKg = _toDouble(user['peso_kg']);
    final alturaCm = _toDouble(user['altura_cm']);
    final pesoHabitualKg = _toDouble(user['peso_habitual_kg']);
    final circunferenciaCinturaCm = _toDouble(user['circunferencia_cintura_cm']);
    final circunferenciaCaderaCm = _toDouble(user['circunferencia_cadera_cm']);
    final imc = _toDouble(user['imc']);
    final icc = _toDouble(user['icc']);
    final tmbKcal = _toDouble(user['tmb_kcal']);
    final getEnergeticoKcal = _toDouble(user['get_energetico_kcal']);
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
      pesoKg: pesoKg,
      alturaCm: alturaCm,
      pesoHabitualKg: pesoHabitualKg,
      circunferenciaCinturaCm: circunferenciaCinturaCm,
      circunferenciaCaderaCm: circunferenciaCaderaCm,
      sexo: user['sexo'] as String?,
      nivelActividad: user['nivel_actividad'] as String?,
      objetivoDietetico: user['objetivo_dietetico'] as String?,
      condicionesMedicas: user['condiciones_medicas'] as String?,
      medicacionActual: user['medicacion_actual'] as String?,
      embarazoLactancia: user['embarazo_lactancia'] as String?,
      imc: imc,
      icc: icc,
      tmbKcal: tmbKcal,
      getEnergeticoKcal: getEnergeticoKcal,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Actualiza el perfil del usuario (name, birth_date, notas, intolerancias, perfil nutricional) vía PATCH /me.
  Future<void> updateProfile({
    required String name,
    DateTime? birthDate,
    String? notas,
    required List<int> intoleranciaIds,
    double? pesoKg,
    double? alturaCm,
    double? pesoHabitualKg,
    double? circunferenciaCinturaCm,
    double? circunferenciaCaderaCm,
    String? sexo,
    String? nivelActividad,
    String? objetivoDietetico,
    String? condicionesMedicas,
    String? medicacionActual,
    String? embarazoLactancia,
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
    body['peso_kg'] = pesoKg;
    body['altura_cm'] = alturaCm;
    body['peso_habitual_kg'] = pesoHabitualKg;
    body['circunferencia_cintura_cm'] = circunferenciaCinturaCm;
    body['circunferencia_cadera_cm'] = circunferenciaCaderaCm;
    body['sexo'] = sexo;
    body['nivel_actividad'] = nivelActividad;
    body['objetivo_dietetico'] = objetivoDietetico;
    body['condiciones_medicas'] = condicionesMedicas;
    body['medicacion_actual'] = medicacionActual;
    body['embarazo_lactancia'] = embarazoLactancia;
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
      final updated = _userFromMap(userMap, prefs);
      final current = userNotifier.value;
      userNotifier.value = AuthUser(
        id: updated.id,
        name: updated.name,
        email: updated.email,
        role: updated.role,
        hogarNombre: updated.hogarNombre ?? current?.hogarNombre,
        avatarUrl: updated.avatarUrl,
        birthDate: updated.birthDate,
        intoleranciaIds: updated.intoleranciaIds,
        notas: updated.notas,
        pesoKg: updated.pesoKg,
        alturaCm: updated.alturaCm,
        pesoHabitualKg: updated.pesoHabitualKg,
        circunferenciaCinturaCm: updated.circunferenciaCinturaCm,
        circunferenciaCaderaCm: updated.circunferenciaCaderaCm,
        sexo: updated.sexo,
        nivelActividad: updated.nivelActividad,
        objetivoDietetico: updated.objetivoDietetico,
        condicionesMedicas: updated.condicionesMedicas,
        medicacionActual: updated.medicacionActual,
        embarazoLactancia: updated.embarazoLactancia,
        imc: updated.imc,
        icc: updated.icc,
        tmbKcal: updated.tmbKcal,
        getEnergeticoKcal: updated.getEnergeticoKcal,
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
  // Perfil nutricional (todos opcionales)
  final double? pesoKg;
  final double? alturaCm;
  final double? pesoHabitualKg;
  final double? circunferenciaCinturaCm;
  final double? circunferenciaCaderaCm;
  final String? sexo;
  final String? nivelActividad;
  final String? objetivoDietetico;
  final String? condicionesMedicas;
  final String? medicacionActual;
  final String? embarazoLactancia;
  // Calculados (solo lectura)
  final double? imc;
  final double? icc;
  final double? tmbKcal;
  final double? getEnergeticoKcal;

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
    this.pesoKg,
    this.alturaCm,
    this.pesoHabitualKg,
    this.circunferenciaCinturaCm,
    this.circunferenciaCaderaCm,
    this.sexo,
    this.nivelActividad,
    this.objetivoDietetico,
    this.condicionesMedicas,
    this.medicacionActual,
    this.embarazoLactancia,
    this.imc,
    this.icc,
    this.tmbKcal,
    this.getEnergeticoKcal,
  });
}
