import 'unidad_medida.dart';

export 'unidad_medida.dart';

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<ElaboracionRecipe>? _parseElaboraciones(dynamic v) {
  if (v == null || v is! List) return null;
  final list = v.whereType<Map<String, dynamic>>().map(ElaboracionRecipe.fromJson).toList();
  return list.isEmpty ? null : list;
}

class Ingredient {
  final int id;
  final String nombre;
  final double? cantidad;
  final int? unidadMedidaId;
  final UnidadMedida? unidadMedida;
  /// Tipos de unidad permitidos para este ingrediente (ej: ['peso', 'volumen']).
  /// Si null o vacío, se muestran todas las unidades no tiempo.
  final List<String>? tiposUnidad;

  const Ingredient({
    required this.id,
    required this.nombre,
    this.cantidad,
    this.unidadMedidaId,
    this.unidadMedida,
    this.tiposUnidad,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    List<String>? tiposUnidad;
    final tu = json['tipos_unidad'];
    if (tu is List) {
      tiposUnidad = tu.whereType<String>().toList();
      if (tiposUnidad.isEmpty) tiposUnidad = null;
    }
    return Ingredient(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] as String?) ?? '',
      cantidad: _parseDouble(json['cantidad']),
      unidadMedidaId: (json['unidad_medida_id'] as num?)?.toInt(),
      unidadMedida: json['unidad_medida'] != null
          ? UnidadMedida.fromJson(json['unidad_medida'] as Map<String, dynamic>)
          : null,
      tiposUnidad: tiposUnidad,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      if (cantidad != null) 'cantidad': cantidad,
      if (unidadMedidaId != null) 'unidad_medida_id': unidadMedidaId,
      if (unidadMedida != null) 'unidad_medida': {
        'id': unidadMedida!.id,
        'nombre': unidadMedida!.nombre,
        'abreviatura': unidadMedida!.abreviatura,
      },
    };
  }
}

/// Paso de elaboración con descripción, tiempo opcional e ingredientes por paso.
class PasoElaboracionRecipe {
  final int id;
  final String descripcion;
  final int? tiempoSegundos;
  final int? tiempoUnidadMedidaId;
  final UnidadMedida? tiempoUnidadMedida;
  final String? temperatura;
  final int orden;
  final List<Ingredient> ingredientes;

  const PasoElaboracionRecipe({
    required this.id,
    required this.descripcion,
    this.tiempoSegundos,
    this.tiempoUnidadMedidaId,
    this.tiempoUnidadMedida,
    this.temperatura,
    required this.orden,
    required this.ingredientes,
  });

  factory PasoElaboracionRecipe.fromJson(Map<String, dynamic> json) {
    final ingJson = (json['ingredientes'] as List<dynamic>?) ?? [];
    final umJson = json['tiempo_unidad_medida'] as Map<String, dynamic>?;
    return PasoElaboracionRecipe(
      id: (json['id'] as num).toInt(),
      descripcion: (json['descripcion'] as String?) ?? '',
      tiempoSegundos: (json['tiempo_segundos'] as num?)?.toInt(),
      tiempoUnidadMedidaId: (json['tiempo_unidad_medida_id'] as num?)?.toInt(),
      tiempoUnidadMedida: umJson != null ? UnidadMedida.fromJson(umJson) : null,
      temperatura: json['temperatura'] as String?,
      orden: (json['orden'] as num?)?.toInt() ?? 0,
      ingredientes: ingJson
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Elaboración (sub-proceso) tipo "La Masa", "El Relleno".
/// [grupoParalelo] es 1-based; null si la elaboración no pertenece a un grupo (se trata como grupo 1).
class ElaboracionRecipe {
  final int id;
  final String titulo;
  final int orden;
  final int? grupoParalelo;
  final List<PasoElaboracionRecipe> pasos;

  const ElaboracionRecipe({
    required this.id,
    required this.titulo,
    required this.orden,
    this.grupoParalelo,
    required this.pasos,
  });

  factory ElaboracionRecipe.fromJson(Map<String, dynamic> json) {
    final pasosJson = (json['pasos'] as List<dynamic>?) ?? [];
    final gp = json['grupo_paralelo'];
    final grupoParalelo = gp is num ? gp.toInt() : (gp is String ? int.tryParse(gp) : null);
    return ElaboracionRecipe(
      id: (json['id'] as num).toInt(),
      titulo: (json['titulo'] as String?) ?? '',
      orden: (json['orden'] as num?)?.toInt() ?? 0,
      grupoParalelo: grupoParalelo,
      pasos: pasosJson
          .map((e) => PasoElaboracionRecipe.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Ingrediente faltante para una receta (planificador), con cantidad y unidad.
class IngredienteFaltante {
  final String nombre;
  final double cantidadFaltante;
  final String unidadAbrev;

  const IngredienteFaltante({
    required this.nombre,
    required this.cantidadFaltante,
    required this.unidadAbrev,
  });

  factory IngredienteFaltante.fromJson(Map<String, dynamic> json) {
    return IngredienteFaltante(
      nombre: (json['ingrediente_nombre'] as String?) ?? '—',
      cantidadFaltante: _parseDouble(json['cantidad_faltante']) ?? 0,
      unidadAbrev: (json['unidad_medida_abrev'] as String?) ?? 'ud.',
    );
  }
}

class Recipe {
  final int id;
  final String titulo;
  final String? imagenUrl;
  final String? descripcion;
  final String? instrucciones;
  final int? tiempoPreparacion;
  final String? dificultad;
  final int? porcionesBase;
  /// Herramientas necesarias (ej. sartén, batidora). Viene de API.
  final List<String>? herramientas;
  final String? estado;
  final double? averageRating;
  final int? userId;
  /// Nombre del autor (viene de API cuando hay user cargado).
  final String? authorName;
  final List<Ingredient> ingredientes;
  /// Semáforo de salud: success, warning, danger, gray (o null si no calculado).
  final String? estadoSalud;
  /// Porcentaje de ingredientes con stock (0-100) o null.
  final int? porcentajeStock;
  /// Si se puede cocinar con el stock del hogar.
  final bool? esCocinable;
  /// Observaciones del administrador (visible para el autor cuando rechazada).
  final String? adminFeedback;
  /// Si la receta fue premiada al ser aprobada.
  final bool? premiada;
  /// Puntos de recompensa (días) asignados al aprobar.
  final int? puntosRecompensa;
  /// Mensaje de salud/intolerancias (planificador), ej. "Contiene lactosa (afecta a…)".
  final String? mensajeSalud;
  /// Ingredientes que faltan en el hogar para esta receta (planificador).
  final List<IngredienteFaltante>? ingredientesFaltantes;
  /// Estado de disponibilidad incluyendo lista de compra: 'disponible' | 'en_camino' | 'faltan' (planificador).
  final String? estadoDisponibilidadCompleta;

  /// Elaboraciones (sub-procesos) con pasos. Para modo chef y visualización estructurada.
  final List<ElaboracionRecipe>? elaboraciones;

  /// Alias de [userId] para compatibilidad con auditoría (identificador del autor).
  int? get authorId => userId;

  /// True si la receta es visible públicamente (estado publicada o aprobada).
  bool get isPublic =>
      estado == 'publicada' || estado == 'aprobada';

  const Recipe({
    required this.id,
    required this.titulo,
    required this.imagenUrl,
    required this.descripcion,
    this.instrucciones,
    required this.tiempoPreparacion,
    required this.dificultad,
    required this.porcionesBase,
    this.herramientas,
    required this.estado,
    required this.averageRating,
    required this.userId,
    this.authorName,
    required this.ingredientes,
    this.estadoSalud,
    this.porcentajeStock,
    this.esCocinable,
    this.adminFeedback,
    this.premiada,
    this.puntosRecompensa,
    this.mensajeSalud,
    this.ingredientesFaltantes,
    this.estadoDisponibilidadCompleta,
    this.elaboraciones,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredientesJson = (json['ingredientes'] as List<dynamic>?) ?? [];
    final faltantesJson = (json['ingredientes_faltantes'] as List<dynamic>?) ?? [];

    return Recipe(
      id: (json['id'] as num).toInt(),
      titulo: (json['titulo'] as String?) ?? '',
      imagenUrl: json['imagen_url'] as String?,
      descripcion: json['descripcion'] as String?,
      instrucciones: json['instrucciones'] as String?,
      tiempoPreparacion: (json['tiempo_preparacion'] as num?)?.toInt(),
      dificultad: json['dificultad'] as String?,
      porcionesBase: (json['porciones_base'] as num?)?.toInt(),
      herramientas: (json['herramientas'] as List<dynamic>?)
          ?.whereType<String>()
          .toList(),
      estado: json['estado'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      userId: (json['user_id'] as num?)?.toInt(),
      authorName: json['author_name'] as String?,
      ingredientes: ingredientesJson
          .map((item) => Ingredient.fromJson(item as Map<String, dynamic>))
          .toList(),
      estadoSalud: json['estado_salud'] as String?,
      porcentajeStock: (json['porcentaje_stock'] as num?)?.toInt(),
      esCocinable: json['es_cocinable'] as bool?,
      adminFeedback: json['admin_feedback'] as String?,
      premiada: json['premiada'] as bool?,
      puntosRecompensa: (json['puntos_recompensa'] as num?)?.toInt(),
      mensajeSalud: json['mensaje_salud'] as String?,
      ingredientesFaltantes: faltantesJson.isEmpty
          ? null
          : faltantesJson
              .whereType<Map<String, dynamic>>()
              .map((e) => IngredienteFaltante.fromJson(e))
              .toList(),
      estadoDisponibilidadCompleta: json['estado_disponibilidad_completa'] as String?,
      elaboraciones: _parseElaboraciones(json['elaboraciones']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'imagen_url': imagenUrl,
      'descripcion': descripcion,
      if (instrucciones != null) 'instrucciones': instrucciones,
      'tiempo_preparacion': tiempoPreparacion,
      'dificultad': dificultad,
      'porciones_base': porcionesBase,
      if (herramientas != null && herramientas!.isNotEmpty) 'herramientas': herramientas,
      'estado': estado,
      'average_rating': averageRating,
      'user_id': userId,
      if (authorName != null) 'author_name': authorName,
      'ingredientes': ingredientes.map((ing) => ing.toJson()).toList(),
      if (estadoSalud != null) 'estado_salud': estadoSalud,
      if (porcentajeStock != null) 'porcentaje_stock': porcentajeStock,
      if (esCocinable != null) 'es_cocinable': esCocinable,
      if (adminFeedback != null) 'admin_feedback': adminFeedback,
      if (premiada != null) 'premiada': premiada,
      if (puntosRecompensa != null) 'puntos_recompensa': puntosRecompensa,
      if (mensajeSalud != null) 'mensaje_salud': mensajeSalud,
      if (ingredientesFaltantes != null)
        'ingredientes_faltantes': ingredientesFaltantes!.map((e) => {
              'ingrediente_nombre': e.nombre,
              'cantidad_faltante': e.cantidadFaltante,
              'unidad_medida_abrev': e.unidadAbrev,
            }).toList(),
      if (estadoDisponibilidadCompleta != null)
        'estado_disponibilidad_completa': estadoDisponibilidadCompleta,
    };
  }
}
