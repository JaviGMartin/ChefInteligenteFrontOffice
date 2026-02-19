class UnidadMedida {
  final int id;
  final String nombre;
  final String? abreviatura;
  final String? tipo;
  final double factorConversion;

  const UnidadMedida({
    required this.id,
    required this.nombre,
    this.abreviatura,
    this.tipo,
    this.factorConversion = 1.0,
  });

  factory UnidadMedida.fromJson(Map<String, dynamic> json) {
    final fc = json['factor_conversion'];
    final factorConversion = fc is num
        ? fc.toDouble()
        : (fc is String ? double.tryParse(fc.replaceAll(',', '.')) : null) ?? 1.0;
    return UnidadMedida(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] as String?) ?? '',
      abreviatura: json['abreviatura'] as String?,
      tipo: json['tipo'] as String?,
      factorConversion: factorConversion,
    );
  }
}
