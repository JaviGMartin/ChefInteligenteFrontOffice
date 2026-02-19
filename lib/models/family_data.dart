import 'hogar_equipo.dart';

class FamilyData {
  final HogarMember tutor;
  final List<HogarMember> dependientes;

  const FamilyData({
    required this.tutor,
    required this.dependientes,
  });

  factory FamilyData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final tutorJson = data['tutor'] as Map<String, dynamic>?;
    final dependientesJson = data['dependientes'] as List<dynamic>? ?? [];
    final tutor = tutorJson != null
        ? HogarMember.fromFamilyJson(tutorJson)
        : throw Exception('Falta tutor en respuesta');
    final dependientes = dependientesJson
        .whereType<Map<String, dynamic>>()
        .map((e) => HogarMember.fromFamilyJson(e))
        .toList();
    return FamilyData(tutor: tutor, dependientes: dependientes);
  }
}
