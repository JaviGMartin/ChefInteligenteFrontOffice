class Inventario {
  final int id;
  final int contenedorId;
  final int productoId;
  final int unidadMedidaId;
  final double cantidad;
  final String? fechaCaducidad;
  final String? fechaApertura;
  final ContenedorRef? contenedor;
  final ProductoRef? producto;
  final UnidadMedidaRef? unidadMedida;

  const Inventario({
    required this.id,
    required this.contenedorId,
    required this.productoId,
    required this.unidadMedidaId,
    required this.cantidad,
    this.fechaCaducidad,
    this.fechaApertura,
    this.contenedor,
    this.producto,
    this.unidadMedida,
  });

  factory Inventario.fromJson(Map<String, dynamic> json) {
    return Inventario(
      id: _toInt(json['id']),
      contenedorId: _toInt(json['contenedor_id']),
      productoId: _toInt(json['producto_id']),
      unidadMedidaId: _toInt(json['unidad_medida_id']),
      cantidad: double.tryParse(json['cantidad'].toString()) ?? 0.0,
      fechaCaducidad: json['fecha_caducidad'] as String?,
      fechaApertura: json['fecha_apertura'] as String?,
      contenedor: json['contenedor'] is Map<String, dynamic>
          ? ContenedorRef.fromJson(json['contenedor'] as Map<String, dynamic>)
          : null,
      producto: json['producto'] is Map<String, dynamic>
          ? ProductoRef.fromJson(json['producto'] as Map<String, dynamic>)
          : null,
      unidadMedida: json['unidad_medida'] is Map<String, dynamic>
          ? UnidadMedidaRef.fromJson(json['unidad_medida'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ContenedorRef {
  final int id;
  final int hogarId;
  final String nombre;
  final String? tipo;

  const ContenedorRef({
    required this.id,
    required this.hogarId,
    required this.nombre,
    this.tipo,
  });

  factory ContenedorRef.fromJson(Map<String, dynamic> json) {
    return ContenedorRef(
      id: _toInt(json['id']),
      hogarId: _toInt(json['hogar_id']),
      nombre: (json['nombre'] as String?) ?? '',
      tipo: json['tipo'] as String?,
    );
  }
}

class ProductoRef {
  final int id;
  final String nombre;
  final String? marca;
  final String? imagenUrl;
  final String? formato;

  const ProductoRef({
    required this.id,
    required this.nombre,
    this.marca,
    this.imagenUrl,
    this.formato,
  });

  factory ProductoRef.fromJson(Map<String, dynamic> json) {
    return ProductoRef(
      id: _toInt(json['id']),
      nombre: (json['nombre'] as String?) ?? '',
      marca: json['marca'] as String?,
      imagenUrl: json['imagen_url'] as String?,
      formato: json['formato'] as String?,
    );
  }
}

class UnidadMedidaRef {
  final int id;
  final String nombre;
  final String? abreviatura;
  final String? tipo;

  const UnidadMedidaRef({
    required this.id,
    required this.nombre,
    this.abreviatura,
    this.tipo,
  });

  factory UnidadMedidaRef.fromJson(Map<String, dynamic> json) {
    return UnidadMedidaRef(
      id: _toInt(json['id']),
      nombre: (json['nombre'] as String?) ?? '',
      abreviatura: json['abreviatura'] as String?,
      tipo: json['tipo'] as String?,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

double _toDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
  return 0;
}
