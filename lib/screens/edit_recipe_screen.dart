import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme/app_colors.dart';
import '../services/recipe_service.dart';
import '../services/stock_service.dart';
import '../widgets/ingrediente_selector.dart';
import '../widgets/main_layout.dart';
import '../widgets/proponer_ingrediente_dialog.dart';
import '../widgets/recipe_form_models.dart';
import '../widgets/recipe_status_badge.dart';

/// Vista de edición de una receta propia (borrador o rechazada).
/// Permite editar título, tiempo, ingredientes y elaboraciones.
class EditRecipeScreen extends StatefulWidget {
  const EditRecipeScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  late final TextEditingController _tituloController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _instruccionesController;
  late final TextEditingController _imagenUrlController;
  late final TextEditingController _tiempoController;
  late final TextEditingController _porcionesController;
  late final TextEditingController _herramientasController;
  String? _dificultad;
  bool _saving = false;
  bool _loading = true;
  String? _loadError;
  Recipe? _fullRecipe;
  List<Ingredient> _ingredientes = [];
  List<UnidadMedida> _unidades = [];
  List<UnidadMedida> get _unidadesTiempo =>
      _unidades.where((u) => u.tipo == 'tiempo').toList();
  /// Unidades para cantidad de ingredientes (excluye tiempo: h, min, s).
  List<UnidadMedida> get _unidadesParaIngredientes =>
      _unidades.where((u) => u.tipo != 'tiempo').toList();

  /// Unidades a mostrar para la fila según el ingrediente seleccionado.
  List<UnidadMedida> _unidadesParaFila(int? ingredienteId) {
    if (ingredienteId == null) return _unidadesParaIngredientes;
    final ing = _ingredientes.where((i) => i.id == ingredienteId).firstOrNull;
    if (ing == null || ing.tiposUnidad == null || ing.tiposUnidad!.isEmpty) {
      return _unidadesParaIngredientes;
    }
    return _unidades.where((u) => (u.tipo != null) && ing.tiposUnidad!.contains(u.tipo!)).toList();
  }
  List<IngredienteRowForm> _rows = [];
  List<ElaboracionForm> _elaboraciones = [];

  bool get _isLocked => (_fullRecipe ?? widget.recipe).estado == 'pendiente';

  bool get _esSolicitudCorreccion =>
      ((_fullRecipe ?? widget.recipe).estado == 'publicada' ||
          (_fullRecipe ?? widget.recipe).estado == 'aprobada');

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.recipe.titulo);
    _descripcionController = TextEditingController(text: widget.recipe.descripcion ?? '');
    _instruccionesController = TextEditingController(text: widget.recipe.instrucciones ?? '');
    _imagenUrlController = TextEditingController(text: widget.recipe.imagenUrl ?? '');
    _tiempoController = TextEditingController(
      text: widget.recipe.tiempoPreparacion?.toString() ?? '',
    );
    _porcionesController = TextEditingController(
      text: widget.recipe.porcionesBase?.toString() ?? '',
    );
    _herramientasController = TextEditingController(
      text: widget.recipe.herramientas?.join(', ') ?? '',
    );
    _dificultad = widget.recipe.dificultad;
    _loadFullData();
  }

  Future<void> _loadFullData() async {
    setState(() => _loading = true);
    try {
      final full = await RecipeService().getRecipe(widget.recipe.id);
      final results = await Future.wait([
        RecipeService().fetchIngredientes(),
        StockService().fetchUnidadesMedida(),
      ]);
      if (!mounted) return;
      final ingredientes = results[0] as List<Ingredient>;
      final unidades = results[1] as List<UnidadMedida>;
      _fullRecipe = full;
      _ingredientes = ingredientes;
      _unidades = unidades;
      _descripcionController.text = full.descripcion ?? '';
      _instruccionesController.text = full.instrucciones ?? '';
      _imagenUrlController.text = full.imagenUrl ?? '';
      _porcionesController.text = full.porcionesBase?.toString() ?? '';
      _herramientasController.text = full.herramientas?.join(', ') ?? '';
      _dificultad = full.dificultad;
      _rows = full.ingredientes.map((ing) => IngredienteRowForm(
        ingredienteId: ing.id,
        cantidadText: (ing.cantidad ?? 0).toString(),
        unidadMedidaId: ing.unidadMedidaId ?? (_unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : null),
      )).toList();
      if (_rows.isEmpty) _rows.add(IngredienteRowForm(unidadMedidaId: _unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : null));
      _elaboraciones = (full.elaboraciones ?? []).map((e) {
        final defaultSegundos = _unidadesTiempo.where((u) => u.factorConversion == 1.0).firstOrNull;
        final pasos = e.pasos.map((p) {
          final ts = p.tiempoSegundos;
          final um = p.tiempoUnidadMedida;
          final factor = (um?.factorConversion ?? 1.0);
          final tiempoDisplay = (ts != null && factor > 0)
              ? (ts / factor).toStringAsFixed(factor >= 1 && factor == factor.roundToDouble() ? 0 : 2)
              : null;
          final umId = p.tiempoUnidadMedidaId ??
              (defaultSegundos?.id ?? (_unidadesTiempo.isNotEmpty ? _unidadesTiempo.first.id : null));
          return PasoForm(
            descripcion: p.descripcion,
            tiempo: tiempoDisplay,
            temperatura: p.temperatura,
            ingredientes: p.ingredientes.map((pi) => PasoIngredienteForm(
              ingredienteId: pi.id,
              cantidad: pi.cantidad ?? 0,
              unidadMedidaId: pi.unidadMedidaId ?? (_unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : 1),
            )).toList(),
            tiempoUnidadMedidaId: umId,
          );
        }).toList();
        if (pasos.isEmpty) pasos.add(PasoForm(tiempoUnidadMedidaId: _unidadesTiempo.isNotEmpty ? _unidadesTiempo.first.id : null));
        return ElaboracionForm(titulo: e.titulo, pasos: pasos);
      }).toList();
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _instruccionesController.dispose();
    _imagenUrlController.dispose();
    _tiempoController.dispose();
    _porcionesController.dispose();
    _herramientasController.dispose();
    for (final e in _elaboraciones) e.dispose();
    super.dispose();
  }

  /// Cantidad ya usada por ingrediente_id en todos los pasos de todas las elaboraciones.
  Map<int, double> _cantidadUsadaPorIngrediente() {
    final mapa = <int, double>{};
    for (final e in _elaboraciones) {
      for (final p in e.pasos) {
        for (final pi in p.ingredientes) {
          mapa[pi.ingredienteId] = (mapa[pi.ingredienteId] ?? 0) + pi.cantidad;
        }
      }
    }
    return mapa;
  }

  /// Primer ingrediente de la receta con cantidad disponible > 0.
  IngredienteRowForm? _primerIngredienteDisponible() {
    final usada = _cantidadUsadaPorIngrediente();
    final recipeIngredientes = _rows
        .where((r) => r.ingredienteId != null && r.cantidad > 0)
        .toList();
    for (final r in recipeIngredientes) {
      final total = r.cantidad;
      final usadaIng = usada[r.ingredienteId!] ?? 0;
      if (total > usadaIng) return r;
    }
    return null;
  }

  /// Valida que la suma por ingrediente en pasos no supere la cantidad en receta.
  String? _validarCantidadesIngredientes() {
    final usada = _cantidadUsadaPorIngrediente();
    final recipeIngredientes = _rows
        .where((r) => r.ingredienteId != null && r.cantidad > 0)
        .toList();
    for (final r in recipeIngredientes) {
      final total = r.cantidad;
      final usadaIng = usada[r.ingredienteId!] ?? 0;
      if (usadaIng > total) {
        final nombre = _ingredientes.where((i) => i.id == r.ingredienteId).map((i) => i.nombre).firstOrNull ?? '—';
        return '«$nombre»: se usan $usadaIng pero la receta tiene $total';
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _buildIngredientesPayload() {
    return _rows
        .where((r) => r.ingredienteId != null && r.cantidad > 0)
        .map((r) {
          final uf = _unidadesParaFila(r.ingredienteId);
          final unidadId = uf.isNotEmpty && (r.unidadMedidaId == null || uf.any((u) => u.id == r.unidadMedidaId))
              ? (r.unidadMedidaId ?? uf.first.id)
              : (uf.isNotEmpty ? uf.first.id : _unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : 1);
          return {
            'ingrediente_id': r.ingredienteId,
            'cantidad': r.cantidad,
            'unidad_medida_id': unidadId,
          };
        })
        .toList();
  }

  List<Map<String, dynamic>> _buildElaboracionesPayload() {
    return _elaboraciones.map((e) {
      final titulo = e.tituloController.text.trim();
      if (titulo.isEmpty) return null;
      return {
        'titulo': titulo,
        'orden': _elaboraciones.indexOf(e),
        'pasos': e.pasos.asMap().entries.map((entry) {
          final p = entry.value;
          final tiempoValor = double.tryParse(p.tiempoController.text.trim());
          final umId = p.tiempoUnidadMedidaId ?? (_unidadesTiempo.isNotEmpty ? _unidadesTiempo.first.id : null);
          return {
            'descripcion': p.descripcionController.text.trim(),
            if (tiempoValor != null) ...{
              'tiempo_valor': tiempoValor,
              if (umId != null) 'tiempo_unidad_medida_id': umId,
            },
            'temperatura': p.temperaturaController.text.trim().isEmpty ? null : p.temperaturaController.text.trim(),
            'orden': entry.key,
            'ingredientes': p.ingredientes.map((pi) => {
              'ingrediente_id': pi.ingredienteId,
              'cantidad': pi.cantidad,
              'unidad_medida_id': pi.unidadMedidaId,
            }).toList(),
          };
        }).toList(),
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _submit() async {
    if (_isLocked) return;
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un título para la receta.')),
      );
      return;
    }
    final errIng = _validarCantidadesIngredientes();
    if (errIng != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingredientes en elaboraciones: $errIng'), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    final tiempo = int.tryParse(_tiempoController.text.trim());
    final porciones = int.tryParse(_porcionesController.text.trim());
    setState(() => _saving = true);
    try {
      final herramientasText = _herramientasController.text.trim();
      final herramientas = herramientasText.isEmpty
          ? <String>[]
          : herramientasText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final updated = await RecipeService().updateRecipe(
        recipeId: widget.recipe.id,
        titulo: titulo,
        descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
        instrucciones: _instruccionesController.text.trim().isEmpty ? null : _instruccionesController.text.trim(),
        imagenUrl: _imagenUrlController.text.trim().isEmpty ? null : _imagenUrlController.text.trim(),
        tiempoPreparacion: tiempo,
        dificultad: _dificultad,
        porcionesBase: porciones,
        herramientas: herramientas.isEmpty ? null : herramientas,
        ingredientes: _buildIngredientesPayload(),
        elaboraciones: _buildElaboracionesPayload(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esSolicitudCorreccion
                ? 'Solicitud de corrección enviada. Un administrador la revisará. No se añadirán puntos adicionales.'
                : '«$titulo» actualizada.',
          ),
          backgroundColor: AppColors.brandGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildElaboracionesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Elaboraciones (opcional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_elaboraciones.length, (eIdx) {
          final elab = _elaboraciones[eIdx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: elab.tituloController,
                          readOnly: _isLocked,
                          decoration: const InputDecoration(
                            labelText: 'Título (ej: La Masa, El Relleno)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _isLocked ? null : () => setState(() {
                          elab.dispose();
                          _elaboraciones.removeAt(eIdx);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(elab.pasos.length, (pIdx) {
                    final paso = elab.pasos[pIdx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Paso ${pIdx + 1}', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 4),
                          TextField(
                            controller: paso.descripcionController,
                            readOnly: _isLocked,
                            decoration: const InputDecoration(
                              labelText: 'Descripción',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLines: 2,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: paso.tiempoController,
                                  readOnly: _isLocked,
                                  decoration: const InputDecoration(
                                    labelText: 'Tiempo',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              if (_unidadesTiempo.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: DropdownButtonFormField<int>(
                                    value: paso.tiempoUnidadMedidaId ?? _unidadesTiempo.first.id,
                                    decoration: const InputDecoration(
                                      labelText: 'Unidad',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: _unidadesTiempo
                                        .map((u) => DropdownMenuItem<int>(
                                              value: u.id,
                                              child: Text(u.abreviatura ?? u.nombre),
                                            ))
                                        .toList(),
                                    onChanged: _isLocked ? null : (v) => setState(() => paso.tiempoUnidadMedidaId = v),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: paso.temperaturaController,
                                  readOnly: _isLocked,
                                  decoration: const InputDecoration(
                                    labelText: 'Temperatura (ej: 180°C)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: _isLocked ? null : (elab.pasos.length > 1
                                    ? () => setState(() {
                                          paso.dispose();
                                          elab.pasos.removeAt(pIdx);
                                        })
                                    : null),
                              ),
                            ],
                          ),
                          if (_rows.any((r) => r.ingredienteId != null)) ...[
                            const SizedBox(height: 4),
                            _buildPasoIngredientes(paso, elab, pIdx),
                          ],
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: _isLocked ? null : () => setState(() => elab.pasos.add(PasoForm(
                      tiempoUnidadMedidaId: _unidadesTiempo.isNotEmpty ? _unidadesTiempo.first.id : null,
                    ))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir paso'),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isLocked ? null : () => setState(() => _elaboraciones.add(ElaboracionForm())),
          icon: const Icon(Icons.add),
          label: const Text('Añadir elaboración'),
        ),
      ],
    );
  }

  Widget _buildPasoIngredientes(PasoForm paso, ElaboracionForm elab, int pIdx) {
    final all = _rows.where((r) => r.ingredienteId != null && r.cantidad > 0).toList();
    // Deduplicar por ingredienteId para evitar "2 or more DropdownMenuItem with same value"
    final seen = <int>{};
    final recipeIngredientes = all.where((r) => seen.add(r.ingredienteId!)).toList();
    if (recipeIngredientes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingredientes para este paso', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        ...paso.ingredientes.asMap().entries.map((entry) {
          final idx = entry.key;
          final pi = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: recipeIngredientes.any((r) => r.ingredienteId == pi.ingredienteId)
                        ? pi.ingredienteId
                        : (recipeIngredientes.isNotEmpty ? recipeIngredientes.first.ingredienteId : null),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: recipeIngredientes
                        .map((r) {
                          final nombre = _ingredientes.where((i) => i.id == r.ingredienteId).map((i) => i.nombre).firstOrNull ?? '—';
                          return DropdownMenuItem<int>(
                            value: r.ingredienteId,
                            child: Text(nombre),
                          );
                        })
                        .toList(),
                    onChanged: _isLocked ? null : (v) {
                      if (v == null) return;
                      final row = _rows.where((r) => r.ingredienteId == v).firstOrNull;
                      if (row != null) {
                        setState(() {
                          pi.ingredienteId = v;
                          pi.cantidad = row.cantidad;
                          pi.unidadMedidaId = row.unidadMedidaId ?? (_unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : pi.unidadMedidaId);
                        });
                      } else {
                        setState(() => pi.ingredienteId = v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    key: ValueKey('cant-$idx-${pi.ingredienteId}-${pi.cantidad}'),
                    initialValue: pi.cantidad.toString(),
                    readOnly: _isLocked,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (s) => setState(() => pi.cantidad = double.tryParse(s.replaceAll(',', '.')) ?? pi.cantidad),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: () {
                      final uf = _unidadesParaFila(pi.ingredienteId);
                      return uf.any((u) => u.id == pi.unidadMedidaId)
                          ? pi.unidadMedidaId
                          : (uf.isNotEmpty ? uf.first.id : null);
                    }(),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: _unidadesParaFila(pi.ingredienteId).map((u) => DropdownMenuItem<int>(value: u.id, child: Text(u.abreviatura ?? u.nombre))).toList(),
                    onChanged: _isLocked ? null : (v) => setState(() => pi.unidadMedidaId = v ?? pi.unidadMedidaId),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _isLocked ? null : () => setState(() => paso.ingredientes.removeAt(idx)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _isLocked ? null : () {
            final disp = _primerIngredienteDisponible();
            if (disp == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No hay ingredientes con cantidad disponible.')),
              );
              return;
            }
            final usada = _cantidadUsadaPorIngrediente();
            final total = disp.cantidad;
            final usadaIng = usada[disp.ingredienteId!] ?? 0;
            final disponible = total - usadaIng;
            setState(() => paso.ingredientes.add(PasoIngredienteForm(
                  ingredienteId: disp.ingredienteId!,
                  cantidad: disponible,
                  unidadMedidaId: disp.unidadMedidaId ?? (_unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : 1),
                )));
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Añadir ingrediente'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _fullRecipe ?? widget.recipe;

    return MainLayout(
      title: 'Editar receta',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _loadError = null;
                            });
                            _loadFullData();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RecipeStatusBadge(estado: recipe.estado),
                      const SizedBox(height: 16),
                      if (_isLocked) _buildPendienteBanner(),
                      if (_esSolicitudCorreccion)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Solicitud de corrección. Los cambios serán revisados por el administrador. No se añadirán puntos adicionales.',
                                  style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_esSolicitudCorreccion) const SizedBox(height: 16),
                      if (recipe.estado == 'rechazada' && (recipe.adminFeedback ?? '').isNotEmpty)
                        _buildRechazadaAlerta(recipe.adminFeedback!),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tituloController,
                        readOnly: _isLocked,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          hintText: 'Nombre de la receta',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descripcionController,
                        readOnly: _isLocked,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          hintText: 'Opcional',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _instruccionesController,
                        readOnly: _isLocked,
                        decoration: const InputDecoration(
                          labelText: 'Instrucciones',
                          hintText: 'Instrucciones generales (opcional si usas elaboraciones)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _imagenUrlController,
                        readOnly: _isLocked,
                        decoration: const InputDecoration(
                          labelText: 'URL de imagen',
                          hintText: 'Opcional',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tiempoController,
                              readOnly: _isLocked,
                              decoration: const InputDecoration(
                                labelText: 'Tiempo (min)',
                                hintText: 'Opcional',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _porcionesController,
                              readOnly: _isLocked,
                              decoration: const InputDecoration(
                                labelText: 'Porciones',
                                hintText: 'Opcional',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dificultad,
                              decoration: const InputDecoration(
                                labelText: 'Dificultad',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('—')),
                                DropdownMenuItem(value: 'facil', child: Text('Fácil')),
                                DropdownMenuItem(value: 'media', child: Text('Media')),
                                DropdownMenuItem(value: 'dificil', child: Text('Difícil')),
                              ],
                              onChanged: _isLocked ? null : (v) => setState(() => _dificultad = v),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _herramientasController,
                            readOnly: _isLocked,
                            decoration: const InputDecoration(
                              labelText: 'Herramientas necesarias',
                              hintText: 'Ej: sartén, batidora, horno (separadas por comas)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ingredientes',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton.icon(
                            onPressed: _isLocked
                                ? null
                                : () async {
                                    final ing = await showProponerIngredienteDialog(context);
                                    if (ing != null && mounted) {
                                      try {
                                        final list = await RecipeService().fetchIngredientes();
                                        if (mounted) {
                                          setState(() {
                                            _ingredientes = list;
                                            _rows.add(IngredienteRowForm(
                                              ingredienteId: ing.id,
                                              cantidadText: '1',
unidadMedidaId: _unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : null,
                                              ));
                                            });
                                          }
                                        } catch (_) {
                                          if (mounted) {
                                            setState(() {
                                              _ingredientes.add(ing);
                                              _rows.add(IngredienteRowForm(
                                                ingredienteId: ing.id,
                                                cantidadText: '1',
                                                unidadMedidaId: _unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : null,
                                            ));
                                          });
                                        }
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.lightbulb_outline),
                            label: const Text('Proponer uno nuevo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_rows.length, (index) {
                        final row = _rows[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: IngredienteSelector(
                                  ingredientes: _ingredientes,
                                  value: _ingredientes.any((i) => i.id == row.ingredienteId)
                                      ? row.ingredienteId
                                      : (_ingredientes.isNotEmpty ? _ingredientes.first.id : null),
                                  onChanged: (v) => setState(() {
                                    row.ingredienteId = v;
                                    final uf = _unidadesParaFila(v);
                                    if (uf.isNotEmpty && (row.unidadMedidaId == null || !uf.any((u) => u.id == row.unidadMedidaId))) {
                                      row.unidadMedidaId = uf.first.id;
                                    }
                                  }),
                                  enabled: !_isLocked,
                                  decoration: const InputDecoration(
                                    labelText: 'Ingrediente',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue: row.cantidadText,
                                  readOnly: _isLocked,
                                  decoration: const InputDecoration(
                                    labelText: 'Cant.',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (s) => setState(() => row.cantidadText = s),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: () {
                                    final uf = _unidadesParaFila(row.ingredienteId);
                                    return uf.any((u) => u.id == row.unidadMedidaId)
                                        ? row.unidadMedidaId
                                        : (uf.isNotEmpty ? uf.first.id : null);
                                  }(),
                                  decoration: const InputDecoration(
                                    labelText: 'Unidad',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _unidadesParaFila(row.ingredienteId)
                                      .map((u) => DropdownMenuItem<int>(
                                            value: u.id,
                                            child: Text(
                                              u.abreviatura ?? u.nombre,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: _isLocked || _unidadesParaFila(row.ingredienteId).isEmpty ? null : (v) => setState(() => row.unidadMedidaId = v),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _isLocked ? null : (_rows.length > 1
                                    ? () => setState(() => _rows.removeAt(index))
                                    : null),
                              ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _isLocked ? null : () => setState(() => _rows.add(IngredienteRowForm(
                                cantidadText: '1',
                                unidadMedidaId: _unidadesParaIngredientes.isNotEmpty ? _unidadesParaIngredientes.first.id : null,
                              ))),
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildElaboracionesSection(),
                      const SizedBox(height: 24),
                      if (!_isLocked)
                        FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _saving
                                ? 'Guardando…'
                                : (_esSolicitudCorreccion ? 'Enviar solicitud de corrección' : 'Guardar cambios'),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPendienteBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        color: AppColors.brandGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.brandBlue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Esta receta está en revisión y no puede ser modificada.',
                  style: TextStyle(
                    color: AppColors.brandBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRechazadaAlerta(String adminFeedback) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Receta rechazada',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Observaciones del administrador:',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                adminFeedback,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
