class Ingredient {
  final int id;
  final String nombre;

  const Ingredient({
    required this.id,
    required this.nombre,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}

class Recipe {
  final int id;
  final String titulo;
  final String? imagenUrl;
  final String? descripcion;
  final int? tiempoPreparacion;
  final String? dificultad;
  final int? porcionesBase;
  final String? estado;
  final double? averageRating;
  final int? userId;
  final List<Ingredient> ingredientes;

  const Recipe({
    required this.id,
    required this.titulo,
    required this.imagenUrl,
    required this.descripcion,
    required this.tiempoPreparacion,
    required this.dificultad,
    required this.porcionesBase,
    required this.estado,
    required this.averageRating,
    required this.userId,
    required this.ingredientes,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredientesJson = (json['ingredientes'] as List<dynamic>?) ?? [];

    return Recipe(
      id: (json['id'] as num).toInt(),
      titulo: (json['titulo'] as String?) ?? '',
      imagenUrl: json['imagen_url'] as String?,
      descripcion: json['descripcion'] as String?,
      tiempoPreparacion: (json['tiempo_preparacion'] as num?)?.toInt(),
      dificultad: json['dificultad'] as String?,
      porcionesBase: (json['porciones_base'] as num?)?.toInt(),
      estado: json['estado'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      userId: (json['user_id'] as num?)?.toInt(),
      ingredientes: ingredientesJson
          .map((item) => Ingredient.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'imagen_url': imagenUrl,
      'descripcion': descripcion,
      'tiempo_preparacion': tiempoPreparacion,
      'dificultad': dificultad,
      'porciones_base': porcionesBase,
      'estado': estado,
      'average_rating': averageRating,
      'user_id': userId,
      'ingredientes': ingredientes.map((ing) => ing.toJson()).toList(),
    };
  }
}
