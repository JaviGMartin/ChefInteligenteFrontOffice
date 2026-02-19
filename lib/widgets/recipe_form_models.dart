import 'package:flutter/material.dart';

/// Una fila del formulario: ingrediente + cantidad + unidad.
class IngredienteRowForm {
  int? ingredienteId;
  String cantidadText;
  int? unidadMedidaId;

  IngredienteRowForm({
    this.ingredienteId,
    this.cantidadText = '1',
    this.unidadMedidaId,
  });

  double get cantidad => double.tryParse(cantidadText.replaceAll(',', '.')) ?? 0;
}

/// Ingrediente asignado a un paso de elaboración.
class PasoIngredienteForm {
  int ingredienteId;
  double cantidad;
  int unidadMedidaId;

  PasoIngredienteForm({
    required this.ingredienteId,
    required this.cantidad,
    required this.unidadMedidaId,
  });
}

/// Paso de elaboración en el formulario.
class PasoForm {
  final TextEditingController descripcionController;
  final TextEditingController tiempoController;
  final TextEditingController temperaturaController;
  List<PasoIngredienteForm> ingredientes;
  int? tiempoUnidadMedidaId;

  PasoForm({
    String descripcion = '',
    String? tiempo,
    String? temperatura,
    List<PasoIngredienteForm>? ingredientes,
    this.tiempoUnidadMedidaId,
  })  : descripcionController = TextEditingController(text: descripcion),
        tiempoController = TextEditingController(text: tiempo ?? ''),
        temperaturaController = TextEditingController(text: temperatura ?? ''),
        ingredientes = ingredientes ?? [];

  void dispose() {
    descripcionController.dispose();
    tiempoController.dispose();
    temperaturaController.dispose();
  }
}

/// Elaboración en el formulario.
class ElaboracionForm {
  final TextEditingController tituloController;
  List<PasoForm> pasos;

  ElaboracionForm({String titulo = '', List<PasoForm>? pasos})
      : tituloController = TextEditingController(text: titulo),
        pasos = pasos ?? [];

  void dispose() {
    tituloController.dispose();
    for (final p in pasos) {
      p.dispose();
    }
  }
}
