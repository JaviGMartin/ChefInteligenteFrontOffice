import 'intolerancia.dart';

class HogarEquipo {
  final int hogarId;
  final String hogarNombre;
  final int currentUserId;
  final bool isOwner;
  final List<HogarMember> miembros;
  /// Límite según plan (Gratis 2, Premium 5, Gold null = ilimitado).
  final int? limiteMiembros;

  const HogarEquipo({
    required this.hogarId,
    required this.hogarNombre,
    required this.currentUserId,
    required this.isOwner,
    required this.miembros,
    this.limiteMiembros,
  });

  factory HogarEquipo.fromJson(Map<String, dynamic> json) {
    final hogar = json['hogar'] as Map<String, dynamic>? ?? {};
    final miembrosJson = json['miembros'] as List<dynamic>? ?? [];
    final limite = hogar['limite_miembros'];
    return HogarEquipo(
      hogarId: (hogar['id'] as num?)?.toInt() ?? 0,
      hogarNombre: (hogar['nombre'] as String?) ?? '',
      currentUserId: (json['current_user_id'] as num?)?.toInt() ?? 0,
      isOwner: (json['is_owner'] as bool?) ?? false,
      miembros: miembrosJson
          .whereType<Map<String, dynamic>>()
          .map((item) => HogarMember.fromJson(item))
          .toList(),
      limiteMiembros: limite is num ? limite.toInt() : null,
    );
  }

  /// True si el plan tiene límite y ya se alcanzó (no se pueden añadir más).
  bool get alLimiteDeMiembros =>
      limiteMiembros != null && miembros.length >= limiteMiembros!;
}

class HogarMember {
  final int id;
  final String name;
  final String? email;
  /// Edad calculada por el backend (desde birth_date). Se mantiene para listados.
  final int? edad;
  /// Fecha de nacimiento (YYYY-MM-DD). Fuente de verdad para edición.
  final String? birthDate;
  /// ID del usuario tutor si es dependiente (perfil ficticio vinculado).
  final int? tutorId;
  final String? rol;
  final bool esPropietario;
  final bool esPrincipal;
  final List<Intolerancia> intolerancias;
  /// URL de la imagen de perfil (desde users.avatar_url).
  final String? avatarUrl;
  /// Notas del usuario (tabla users, fuente única de verdad).
  final String? notas;
  /// Tipo de miembro en el hogar: 'titular' | 'invitado' | 'dependiente'.
  final String? tipoMiembro;

  const HogarMember({
    required this.id,
    required this.name,
    required this.email,
    this.edad,
    this.birthDate,
    this.tutorId,
    required this.rol,
    required this.esPropietario,
    required this.esPrincipal,
    required this.intolerancias,
    this.avatarUrl,
    this.notas,
    this.tipoMiembro,
  });

  /// True si es miembro sin cuenta (perfil fantasma).
  bool get esFicticio => email == null || email!.isEmpty;

  /// Desde la respuesta de GET /me/dependientes (tutor o dependiente).
  factory HogarMember.fromFamilyJson(Map<String, dynamic> json) {
    final intoleranciasJson = json['intolerancias'] as List<dynamic>? ?? [];
    final avatarUrl = json['avatar_url'] as String?;
    final birthDate = json['birth_date'] as String?;
    final tutorId = json['tutor_id'];
    final esTutor = (json['es_tutor'] as bool?) ?? false;
    final edad = json['edad'];
    return HogarMember(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      email: json['email'] as String?,
      edad: edad is num ? edad.toInt() : null,
      birthDate: birthDate != null && birthDate.isNotEmpty ? birthDate : null,
      tutorId: tutorId is num ? tutorId.toInt() : null,
      rol: esTutor ? 'propietario' : 'miembro',
      esPropietario: esTutor,
      esPrincipal: esTutor,
      intolerancias: intoleranciasJson
          .whereType<Map<String, dynamic>>()
          .map((e) => Intolerancia.fromJson(e))
          .toList(),
      avatarUrl: avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null,
      notas: null,
    );
  }

  factory HogarMember.fromJson(Map<String, dynamic> json) {
    final pivot = json['pivot'] as Map<String, dynamic>? ?? {};
    final intoleranciasJson = json['intolerancias'] as List<dynamic>? ?? [];
    final avatarUrl = json['avatar_url'] as String?;
    final notas = json['notas'] as String?;
    final edad = json['edad'];
    final birthDate = json['birth_date'] as String?;
    final tutorId = json['tutor_id'];
    return HogarMember(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      email: json['email'] as String?,
      edad: edad is num ? edad.toInt() : null,
      birthDate: birthDate != null && birthDate.isNotEmpty ? birthDate : null,
      tutorId: tutorId is num ? tutorId.toInt() : null,
      rol: pivot['rol'] as String?,
      esPropietario: (json['es_propietario'] as bool?) ?? false,
      esPrincipal: (pivot['es_principal'] as bool?) ?? false,
      intolerancias: intoleranciasJson
          .whereType<Map<String, dynamic>>()
          .map((item) => Intolerancia.fromJson(item))
          .toList(),
      avatarUrl: avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null,
      notas: notas != null && notas.isNotEmpty ? notas : null,
      tipoMiembro: json['tipo_miembro'] as String?,
    );
  }
}
