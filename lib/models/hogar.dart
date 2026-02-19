class Hogar {
  final int id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final bool esPrincipal;

  const Hogar({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    required this.esPrincipal,
  });

  factory Hogar.fromJson(Map<String, dynamic> json) {
    final pivot = json['pivot'] as Map<String, dynamic>?;
    return Hogar(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] as String?) ?? '',
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      esPrincipal: (pivot?['es_principal'] as bool?) ?? false,
    );
  }
}
