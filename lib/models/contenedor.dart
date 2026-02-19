class Contenedor {
  final int id;
  final int hogarId;
  final String? hogarNombre;
  final String nombre;
  final String? tipo;
  final double? capacidad;
  final String? ubicacion;

  const Contenedor({
    required this.id,
    required this.hogarId,
    this.hogarNombre,
    required this.nombre,
    this.tipo,
    this.capacidad,
    this.ubicacion,
  });

  factory Contenedor.fromJson(Map<String, dynamic> json) {
    return Contenedor(
      id: (json['id'] as num).toInt(),
      hogarId: (json['hogar_id'] as num).toInt(),
      hogarNombre: json['hogar_nombre'] as String?,
      nombre: (json['nombre'] as String?) ?? '',
      tipo: json['tipo'] as String?,
      capacidad: (json['capacidad'] as num?)?.toDouble(),
      ubicacion: json['ubicacion'] as String?,
    );
  }
}
