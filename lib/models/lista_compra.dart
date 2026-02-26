/// Cabecera de lista de compra (listas_compra) con ítems.
class ListaCompraCabecera {
  final int id;
  final String titulo;
  final int hogarId;
  final int userId;
  final int? proveedorId;
  final bool archivada;
  final bool pendienteProcesar;
  final String? fechaPrevista;
  final String? fechaProcesado;
  final List<ListaCompraItem> items;

  const ListaCompraCabecera({
    required this.id,
    required this.titulo,
    required this.hogarId,
    required this.userId,
    this.proveedorId,
    required this.archivada,
    this.pendienteProcesar = false,
    this.fechaPrevista,
    this.fechaProcesado,
    this.items = const [],
  });

  factory ListaCompraCabecera.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return ListaCompraCabecera(
      id: _toInt(json['id']),
      titulo: (json['titulo'] as String?) ?? '',
      hogarId: _toInt(json['hogar_id']),
      userId: _toInt(json['user_id']),
      proveedorId: _toIntNullable(json['proveedor_id']),
      archivada: json['archivada'] == true,
      pendienteProcesar: json['pendiente_procesar'] == true,
      fechaPrevista: json['fecha_prevista'] as String?,
      fechaProcesado: json['fecha_procesado'] as String?,
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map((e) => ListaCompraItem.fromJson(e))
          .toList(),
    );
  }
}

/// Ítem de una lista de compra (lista_compra).
class ListaCompraItem {
  final int id;
  final int listasCompraId;
  final int? productoId;
  final ProductoRef? producto;
  final double cantidad;
  final double cantidadCompra;
  final int? unidadMedidaId;
  final UnidadMedidaRef? unidadMedida;
  /// Formato del catálogo (pack, bric, etc.) cuando el ítem tiene producto_proveedor.
  final String? formato;
  final bool completado;
  final String estado;
  final int? contenedorId;
  final ContenedorRef? contenedor;

  const ListaCompraItem({
    required this.id,
    required this.listasCompraId,
    this.productoId,
    this.producto,
    required this.cantidad,
    required this.cantidadCompra,
    this.unidadMedidaId,
    this.unidadMedida,
    this.formato,
    required this.completado,
    required this.estado,
    this.contenedorId,
    this.contenedor,
  });

  factory ListaCompraItem.fromJson(Map<String, dynamic> json) {
    return ListaCompraItem(
      id: _toInt(json['id']),
      listasCompraId: _toInt(json['listas_compra_id']),
      productoId: _toIntNullable(json['producto_id']),
      producto: json['producto'] is Map<String, dynamic>
          ? ProductoRef.fromJson(json['producto'] as Map<String, dynamic>)
          : null,
      cantidad: _toDouble(json['cantidad']),
      cantidadCompra: _toDouble(json['cantidad_compra']),
      unidadMedidaId: _toIntNullable(json['unidad_medida_id']),
      unidadMedida: json['unidad_medida'] is Map<String, dynamic>
          ? UnidadMedidaRef.fromJson(json['unidad_medida'] as Map<String, dynamic>)
          : null,
      formato: json['formato'] as String?,
      completado: json['completado'] == true,
      estado: (json['estado'] as String?) ?? 'pendiente',
      contenedorId: _toIntNullable(json['contenedor_id']),
      contenedor: json['contenedor'] is Map<String, dynamic>
          ? ContenedorRef.fromJson(json['contenedor'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Texto corto para cantidad + empaquetado (ej. "2 pack", "1 bric").
  String get cantidadYEmpaquetado {
    final emp = (formato?.trim().isNotEmpty == true)
        ? formato!
        : (unidadMedida?.abreviatura ?? unidadMedida?.nombre ?? 'ud.');
    final c = cantidad;
    final cantStr = c == c.roundToDouble() ? c.toInt().toString() : c.toString();
    return '$cantStr $emp'.trim();
  }
}

class ProductoRef {
  final int id;
  final String nombre;
  final String? marca;

  const ProductoRef({required this.id, required this.nombre, this.marca});

  factory ProductoRef.fromJson(Map<String, dynamic> json) {
    return ProductoRef(
      id: _toInt(json['id']),
      nombre: (json['nombre'] as String?) ?? '',
      marca: json['marca'] as String?,
    );
  }
}

class UnidadMedidaRef {
  final int id;
  final String nombre;
  final String? abreviatura;

  const UnidadMedidaRef({
    required this.id,
    required this.nombre,
    this.abreviatura,
  });

  factory UnidadMedidaRef.fromJson(Map<String, dynamic> json) {
    return UnidadMedidaRef(
      id: _toInt(json['id']),
      nombre: (json['nombre'] as String?) ?? '',
      abreviatura: json['abreviatura'] as String?,
    );
  }
}

class ContenedorRef {
  final int id;
  final String nombre;
  final String? tipo;

  const ContenedorRef({
    required this.id,
    required this.nombre,
    this.tipo,
  });

  factory ContenedorRef.fromJson(Map<String, dynamic> json) {
    return ContenedorRef(
      id: _toInt(json['id']),
      nombre: (json['nombre'] as String?) ?? '',
      tipo: json['tipo'] as String?,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _toIntNullable(dynamic value) {
  if (value == null) return null;
  final i = _toInt(value);
  return i;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}
