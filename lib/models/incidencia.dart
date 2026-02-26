/// Incidencia o propuesta enviada por el usuario; el admin responde en el panel.
class Incidencia {
  final int id;
  final int userId;
  final String tipo; // incidencia | propuesta
  final String? contexto; // general | receta | ingrediente
  final int? recetaId;
  final int? ingredienteId;
  final String asunto;
  final String cuerpo;
  final String estado; // nuevo | en_curso | resuelto | cerrado
  final int? asignadoA;
  final String createdAt;
  final String updatedAt;
  final List<IncidenciaMensaje> mensajes;

  const Incidencia({
    required this.id,
    required this.userId,
    required this.tipo,
    this.contexto,
    this.recetaId,
    this.ingredienteId,
    required this.asunto,
    required this.cuerpo,
    required this.estado,
    this.asignadoA,
    required this.createdAt,
    required this.updatedAt,
    this.mensajes = const [],
  });

  factory Incidencia.fromJson(Map<String, dynamic> json) {
    final mensajesList = json['mensajes'] as List<dynamic>? ?? [];
    return Incidencia(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      tipo: (json['tipo'] as String?) ?? 'incidencia',
      contexto: json['contexto'] as String?,
      recetaId: (json['receta_id'] as num?)?.toInt(),
      ingredienteId: (json['ingrediente_id'] as num?)?.toInt(),
      asunto: (json['asunto'] as String?) ?? '',
      cuerpo: (json['cuerpo'] as String?) ?? '',
      estado: (json['estado'] as String?) ?? 'nuevo',
      asignadoA: (json['asignado_a'] as num?)?.toInt(),
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
      mensajes: mensajesList
          .whereType<Map<String, dynamic>>()
          .map((m) => IncidenciaMensaje.fromJson(m))
          .toList(),
    );
  }

  String get tipoLabel => tipo == 'propuesta' ? 'Propuesta' : 'Incidencia';
  String get estadoLabel {
    switch (estado) {
      case 'nuevo':
        return 'Nuevo';
      case 'en_curso':
        return 'En curso';
      case 'resuelto':
        return 'Resuelto';
      case 'cerrado':
        return 'Cerrado';
      default:
        return estado;
    }
  }
}

/// Mensaje de respuesta dentro de un hilo de incidencia.
class IncidenciaMensaje {
  final int id;
  final int incidenciaId;
  final int userId;
  final String mensaje;
  final String createdAt;

  const IncidenciaMensaje({
    required this.id,
    required this.incidenciaId,
    required this.userId,
    required this.mensaje,
    required this.createdAt,
  });

  factory IncidenciaMensaje.fromJson(Map<String, dynamic> json) {
    return IncidenciaMensaje(
      id: (json['id'] as num).toInt(),
      incidenciaId: (json['incidencia_id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      mensaje: (json['mensaje'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}
