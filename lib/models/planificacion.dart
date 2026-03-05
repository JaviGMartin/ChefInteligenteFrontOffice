class Planificacion {
  final int id;
  final int recetaId;
  final String fecha;
  final String toma;
  final bool cocinada;
  final PlanificacionReceta? receta;
  /// Porcentaje de ingredientes con stock (0-100) o null si no calculado.
  final int? porcentajeStock;
  /// Si se puede cocinar con el stock del hogar.
  final bool? esCocinable;
  /// Semáforo de salud: success, warning, danger, gray.
  final String? estadoSalud;
  /// Mensaje de alertas de intolerancias.
  final String? mensajeSalud;
  /// Estado de disponibilidad: 'disponible', 'en_camino' (ingredientes en lista de compra), 'faltan'.
  final String? estadoDisponibilidadCompleta;

  const Planificacion({
    required this.id,
    required this.recetaId,
    required this.fecha,
    required this.toma,
    required this.cocinada,
    this.receta,
    this.porcentajeStock,
    this.esCocinable,
    this.estadoSalud,
    this.mensajeSalud,
    this.estadoDisponibilidadCompleta,
  });

  factory Planificacion.fromJson(Map<String, dynamic> json) {
    return Planificacion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      recetaId: (json['receta_id'] as num?)?.toInt() ?? 0,
      fecha: (json['fecha'] as String?) ?? '',
      toma: (json['toma'] as String?) ?? '',
      cocinada: (json['cocinada'] as bool?) ?? false,
      receta: json['receta'] is Map<String, dynamic>
          ? PlanificacionReceta.fromJson(json['receta'] as Map<String, dynamic>)
          : null,
      porcentajeStock: (json['porcentaje_stock'] as num?)?.toInt(),
      esCocinable: json['es_cocinable'] as bool?,
      estadoSalud: json['estado_salud'] as String?,
      mensajeSalud: json['mensaje_salud'] as String?,
      estadoDisponibilidadCompleta: json['estado_disponibilidad_completa'] as String?,
    );
  }
}

class PlanificacionReceta {
  final int id;
  final String titulo;
  final String? imagenUrl;

  const PlanificacionReceta({
    required this.id,
    required this.titulo,
    this.imagenUrl,
  });

  factory PlanificacionReceta.fromJson(Map<String, dynamic> json) {
    return PlanificacionReceta(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titulo: (json['titulo'] as String?) ?? '—',
      imagenUrl: json['imagen_url'] as String?,
    );
  }
}
