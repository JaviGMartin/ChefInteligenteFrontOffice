class Hogar {
  final int id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final bool esPrincipal;
  /// Último supermercado/proveedor usado para listas (por hogar).
  final int? ultimoProveedorId;

  const Hogar({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    required this.esPrincipal,
    this.ultimoProveedorId,
  });

  factory Hogar.fromJson(Map<String, dynamic> json) {
    final pivot = json['pivot'] as Map<String, dynamic>?;
    final up = json['ultimo_proveedor_id'];
    return Hogar(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] as String?) ?? '',
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      esPrincipal: (pivot?['es_principal'] as bool?) ?? false,
      ultimoProveedorId: up is int ? up : (up is num ? up.toInt() : null),
    );
  }
}
