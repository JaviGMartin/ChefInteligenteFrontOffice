import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/stock_service.dart';
import '../widgets/main_layout.dart';

/// Una fila del formulario: ingrediente + cantidad + unidad.
class _IngredienteRow {
  int? ingredienteId;
  String cantidadText;
  int? unidadMedidaId;

  _IngredienteRow({
    this.ingredienteId,
    this.cantidadText = '1',
    this.unidadMedidaId,
  });

  double get cantidad => double.tryParse(cantidadText.replaceAll(',', '.')) ?? 0;
}

/// Paso de elaboración en el formulario.
class _PasoForm {
  final TextEditingController descripcionController;
  final TextEditingController tiempoController;
  final TextEditingController temperaturaController;
  List<_PasoIngredienteForm> ingredientes;
  int? tiempoUnidadMedidaId;

  _PasoForm({
    String descripcion = '',
    String? tiempo,
    String? temperatura,
    List<_PasoIngredienteForm>? ingredientes,
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

/// Ingrediente asignado a un paso.
class _PasoIngredienteForm {
  int ingredienteId;
  double cantidad;
  int unidadMedidaId;

  _PasoIngredienteForm({
    required this.ingredienteId,
    required this.cantidad,
    required this.unidadMedidaId,
  });
}

/// Elaboración en el formulario.
class _ElaboracionForm {
  final TextEditingController tituloController;
  List<_PasoForm> pasos;

  _ElaboracionForm({String titulo = '', List<_PasoForm>? pasos})
      : tituloController = TextEditingController(text: titulo),
        pasos = pasos ?? [];

  void dispose() {
    tituloController.dispose();
    for (final p in pasos) {
      p.dispose();
    }
  }
}

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _instruccionesController = TextEditingController();
  final _imagenUrlController = TextEditingController();
  final _tiempoController = TextEditingController();
  final _porcionesController = TextEditingController();
  String? _dificultad;
  List<_IngredienteRow> _rows = [_IngredienteRow()];
  final List<_ElaboracionForm> _elaboraciones = [];
  bool _saving = false;

  List<Ingredient> _ingredientes = [];
  List<UnidadMedida> _unidades = [];
  List<UnidadMedida> get _unidadesTiempo =>
      _unidades.where((u) => u.tipo == 'tiempo').toList();
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        RecipeService().fetchIngredientes(),
        StockService().fetchUnidadesMedida(),
      ]);
      if (mounted) {
        setState(() {
          _ingredientes = results[0] as List<Ingredient>;
          _unidades = results[1] as List<UnidadMedida>;
          _loading = false;
          if (_rows.isNotEmpty && _rows.first.unidadMedidaId == null && _unidades.isNotEmpty) {
            _rows = _rows.map((r) => _IngredienteRow(
              ingredienteId: r.ingredienteId,
              cantidadText: r.cantidadText,
              unidadMedidaId: r.unidadMedidaId ?? _unidades.first.id,
            )).toList();
          }
        });
      }
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
    for (final e in _elaboraciones) {
      e.dispose();
    }
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
  _IngredienteRow? _primerIngredienteDisponible() {
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

  List<Map<String, dynamic>> _buildElaboracionesPayload() {
    return _elaboraciones.map((e) {
      final titulo = e.tituloController.text.trim();
      if (titulo.isEmpty) return null;
      return {
        'titulo': titulo,
        'orden': _elaboraciones.indexOf(e),
        'pasos': e.pasos.asMap().entries.map((entry) {
          final p = entry.value;
          final desc = p.descripcionController.text.trim();
          if (desc.isEmpty) return null;
          final tiempoValor = double.tryParse(p.tiempoController.text.trim());
          final umId = p.tiempoUnidadMedidaId ?? (_unidadesTiempo.isNotEmpty ? _unidadesTiempo.first.id : null);
          return {
            'descripcion': desc,
            if (tiempoValor != null) ...{
              'tiempo_valor': tiempoValor,
              if (umId != null) 'tiempo_unidad_medida_id': umId,
            },
            'temperatura': p.temperaturaController.text.trim().isEmpty
                ? null
                : p.temperaturaController.text.trim(),
            'orden': entry.key,
            'ingredientes': p.ingredientes
                .map((i) => {
                      'ingrediente_id': i.ingredienteId,
                      'cantidad': i.cantidad,
                      'unidad_medida_id': i.unidadMedidaId,
                    })
                .toList(),
          };
        }).whereType<Map<String, dynamic>>().toList(),
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _buildIngredientesPayload() {
    return _rows
        .where((r) => r.ingredienteId != null && r.cantidad > 0)
        .map((r) => {
              'ingrediente_id': r.ingredienteId!,
              'cantidad': r.cantidad,
              if (r.unidadMedidaId != null) 'unidad_medida_id': r.unidadMedidaId,
            })
        .toList();
  }

  Future<void> _submit() async {
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
    final ingredientes = _buildIngredientesPayload();
    final elaboraciones = _buildElaboracionesPayload();

    setState(() => _saving = true);
    try {
      final recipe = await RecipeService().createRecipe(
        titulo: titulo,
        descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
        instrucciones: _instruccionesController.text.trim().isEmpty ? null : _instruccionesController.text.trim(),
        imagenUrl: _imagenUrlController.text.trim().isEmpty ? null : _imagenUrlController.text.trim(),
        tiempoPreparacion: tiempo,
        dificultad: _dificultad,
        porcionesBase: porciones,
        ingredientes: ingredientes.isEmpty ? null : ingredientes,
        elaboraciones: elaboraciones.isEmpty ? null : elaboraciones,
      );
      if (!mounted) return;
      Navigator.of(context).pop(recipe);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${recipe.titulo}» creada.'),
          backgroundColor: Colors.green.shade700,
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
                        onPressed: () => setState(() => _elaboraciones.removeAt(eIdx)),
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
                                    onChanged: (v) => setState(() => paso.tiempoUnidadMedidaId = v),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: paso.temperaturaController,
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
                                onPressed: elab.pasos.length > 1
                                    ? () => setState(() {
                                          paso.dispose();
                                          elab.pasos.removeAt(pIdx);
                                        })
                                    : null,
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
                    onPressed: () {
                      setState(() => elab.pasos.add(_PasoForm(tiempoUnidadMedidaId: _unidadesTiempo.isNotEmpty ? _unidadesTiempo.first.id : null)));
                    },
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
          onPressed: () => setState(() => _elaboraciones.add(_ElaboracionForm())),
          icon: const Icon(Icons.add),
          label: const Text('Añadir elaboración'),
        ),
      ],
    );
  }

  Widget _buildPasoIngredientes(_PasoForm paso, _ElaboracionForm elab, int pIdx) {
    final all = _rows.where((r) => r.ingredienteId != null && r.cantidad > 0).toList();
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
                          final idx = _ingredientes.indexWhere((i) => i.id == r.ingredienteId);
                          final nombre = idx >= 0 ? _ingredientes[idx].nombre : '—';
                          return DropdownMenuItem<int>(
                            value: r.ingredienteId,
                            child: Text(nombre),
                          );
                        })
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final row = _rows.where((r) => r.ingredienteId == v).firstOrNull;
                      if (row != null) {
                        setState(() {
                          pi.ingredienteId = v;
                          pi.cantidad = row.cantidad;
                          pi.unidadMedidaId = row.unidadMedidaId ?? (_unidades.isNotEmpty ? _unidades.first.id : pi.unidadMedidaId);
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
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (s) => setState(() => pi.cantidad = double.tryParse(s.replaceAll(',', '.')) ?? pi.cantidad),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: pi.unidadMedidaId,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: _unidades.map((u) => DropdownMenuItem<int>(value: u.id, child: Text(u.abreviatura ?? u.nombre))).toList(),
                    onChanged: (v) => setState(() => pi.unidadMedidaId = v ?? pi.unidadMedidaId),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => paso.ingredientes.removeAt(idx)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
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
            setState(() => paso.ingredientes.add(_PasoIngredienteForm(
                  ingredienteId: disp.ingredienteId!,
                  cantidad: disponible,
                  unidadMedidaId: disp.unidadMedidaId ?? (_unidades.isNotEmpty ? _unidades.first.id : 1),
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
    return MainLayout(
      title: 'Nueva receta',
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
                            _loadData();
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
                      TextField(
                        controller: _tituloController,
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
                              decoration: const InputDecoration(
                                labelText: 'Porciones',
                                hintText: 'Opcional',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
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
                              onChanged: (v) => setState(() => _dificultad = v),
                            ),
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
                            onPressed: () {
                              setState(() {
                                _rows.add(_IngredienteRow(
                                  cantidadText: '1',
                                  unidadMedidaId: _unidades.isNotEmpty ? _unidades.first.id : null,
                                ));
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir'),
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
                                child: DropdownButtonFormField<int>(
                                  value: row.ingredienteId,
                                  decoration: const InputDecoration(
                                    labelText: 'Ingrediente',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _ingredientes
                                      .map((i) => DropdownMenuItem<int>(
                                            value: i.id,
                                            child: Text(
                                              i.nombre,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => row.ingredienteId = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue: row.cantidadText,
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
                                  value: row.unidadMedidaId ?? (_unidades.isNotEmpty ? _unidades.first.id : null),
                                  decoration: const InputDecoration(
                                    labelText: 'Unidad',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _unidades
                                      .map((u) => DropdownMenuItem<int>(
                                            value: u.id,
                                            child: Text(
                                              u.abreviatura ?? u.nombre,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: _unidades.isEmpty ? null : (v) => setState(() => row.unidadMedidaId = v),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _rows.length > 1
                                    ? () => setState(() => _rows.removeAt(index))
                                    : null,
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      _buildElaboracionesSection(),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Guardando…' : 'Crear receta'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
