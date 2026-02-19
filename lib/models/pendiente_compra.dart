/// Ítem del embudo de compra (pendientes_compra): ingrediente pendiente de asignar a lista.
class PendienteCompra {
  final int id;
  final int userId;
  final int hogarId;
  final int ingredienteId;
  final IngredienteRef? ingrediente;
  final int? recetaId;
  final String? recetaTitulo;
  final List<dynamic>? origenes;
  final double cantidad;
  final double cantidadCompra;
  final int? unidadMedidaId;
  final UnidadMedidaRef? unidadMedida;
  final int? productoId;
  final ProductoRef? producto;
  final int? listaDestinoId;
  final ListaDestinoRef? listaDestino;

  const PendienteCompra({
    required this.id,
    required this.userId,
    required this.hogarId,
    required this.ingredienteId,
    this.ingrediente,
    this.recetaId,
    this.recetaTitulo,
    this.origenes,
    required this.cantidad,
    required this.cantidadCompra,
    this.unidadMedidaId,
    this.unidadMedida,
    this.productoId,
    this.producto,
    this.listaDestinoId,
    this.listaDestino,
  });

  factory PendienteCompra.fromJson(Map<String, dynamic> json) {
    return PendienteCompra(
      id: _toInt(json['id']),
      userId: _toInt(json['user_id']),
      hogarId: _toInt(json['hogar_id']),
      ingredienteId: _toInt(json['ingrediente_id']),
      ingrediente: json['ingrediente'] is Map<String, dynamic>
          ? IngredienteRef.fromJson(json['ingrediente'] as Map<String, dynamic>)
          : null,
      recetaId: _toIntNullable(json['receta_id']),
      recetaTitulo: json['receta_titulo'] as String?,
      origenes: json['origenes'] as List<dynamic>?,
      cantidad: _toDouble(json['cantidad']),
      cantidadCompra: _toDouble(json['cantidad_compra']),
      unidadMedidaId: _toIntNullable(json['unidad_medida_id']),
      unidadMedida: json['unidad_medida'] is Map<String, dynamic>
          ? UnidadMedidaRef.fromJson(json['unidad_medida'] as Map<String, dynamic>)
          : null,
      productoId: _toIntNullable(json['producto_id']),
      producto: json['producto'] is Map<String, dynamic>
          ? ProductoRef.fromJson(json['producto'] as Map<String, dynamic>)
          : null,
      listaDestinoId: _toIntNullable(json['lista_destino_id']),
      listaDestino: json['lista_destino'] is Map<String, dynamic>
          ? ListaDestinoRef.fromJson(json['lista_destino'] as Map<String, dynamic>)
          : null,
    );
  }

  String get displayNombre => ingrediente?.nombre ?? 'Ingrediente #$ingredienteId';
  String get cantidadTexto {
    final u = unidadMedida?.abreviatura ?? unidadMedida?.nombre ?? '';
    final c = cantidadCompra == cantidadCompra.truncate()
        ? cantidadCompra.toInt().toString()
        : cantidadCompra.toString();
    return u.isNotEmpty ? '$c $u' : c;
  }

  /// Texto con todas las recetas de origen (ej. "Receta: Espaguetis boloñesa" o "Recetas: Espaguetis boloñesa (250 gr), Pruebas (500 gr)").
  String? get textoOrigenes {
    final list = origenes;
    if (list == null || list.isEmpty) {
      return recetaTitulo != null && recetaTitulo!.isNotEmpty ? 'Receta: $recetaTitulo' : null;
    }
    final partes = <String>[];
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final titulo = (e['receta_titulo'] as String?)?.trim() ?? '—';
      final cant = e['cantidad'];
      final abrev = (e['unidad_abrev'] as String?)?.trim() ?? '';
      if (cant != null && cant is num && abrev.isNotEmpty) {
        final c = cant == cant.truncate() ? cant.toInt().toString() : cant.toString();
        partes.add('$titulo ($c $abrev)');
      } else {
        partes.add(titulo);
      }
    }
    if (partes.isEmpty) return recetaTitulo != null && recetaTitulo!.isNotEmpty ? 'Receta: $recetaTitulo' : null;
    return partes.length == 1 ? 'Receta: ${partes.single}' : 'Recetas: ${partes.join(', ')}';
  }
}

class IngredienteRef {
  final int id;
  final String nombre;
  final String? categoria;

  const IngredienteRef({required this.id, required this.nombre, this.categoria});

  factory IngredienteRef.fromJson(Map<String, dynamic> json) {
    return IngredienteRef(
      id: _toInt(json['id']),
      nombre: (json['nombre'] as String?) ?? '',
      categoria: json['categoria'] as String?,
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

class ListaDestinoRef {
  final int id;
  final String titulo;

  const ListaDestinoRef({required this.id, required this.titulo});

  factory ListaDestinoRef.fromJson(Map<String, dynamic> json) {
    return ListaDestinoRef(
      id: _toInt(json['id']),
      titulo: (json['titulo'] as String?) ?? '',
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
  return i == 0 && value != 0 ? null : i;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}
