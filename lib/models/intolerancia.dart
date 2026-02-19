class Intolerancia {
  final int id;
  final String nombre;

  const Intolerancia({
    required this.id,
    required this.nombre,
  });

  factory Intolerancia.fromJson(Map<String, dynamic> json) {
    return Intolerancia(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] as String?) ?? '',
    );
  }
}
