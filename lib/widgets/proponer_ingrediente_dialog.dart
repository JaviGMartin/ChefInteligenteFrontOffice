import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/ingrediente_service.dart';
import '../theme/app_colors.dart';

/// Diálogo para proponer un ingrediente nuevo (propuesta; admin lo verificará después).
/// Devuelve el [Ingredient] creado o null si se canceló o falló.
Future<Ingredient?> showProponerIngredienteDialog(BuildContext context) {
  return showDialog<Ingredient?>(
    context: context,
    builder: (context) => const _ProponerIngredienteDialog(),
  );
}

class _ProponerIngredienteDialog extends StatefulWidget {
  const _ProponerIngredienteDialog();

  @override
  State<_ProponerIngredienteDialog> createState() => _ProponerIngredienteDialogState();
}

class _ProponerIngredienteDialogState extends State<_ProponerIngredienteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();

  List<CategoriaIngrediente> _categorias = [];
  int? _categoriaId;
  bool _loading = true;
  String? _loadError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _loadCategorias() async {
    try {
      final list = await IngredienteService().fetchCategoriasIngrediente();
      if (mounted) {
        setState(() {
          _categorias = list;
          _loading = false;
          if (list.isNotEmpty && _categoriaId == null) {
            _categoriaId = list.first.id;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    final nombre = _nombreController.text.trim();
    final catId = _categoriaId;
    if (catId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige una categoría')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final ing = await IngredienteService().crearIngrediente(
        nombre: nombre,
        categoriaIngredienteId: catId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${ing.nombre}" se ha propuesto. Lo verá el equipo y quedará disponible para todos cuando lo aprueben.'),
          backgroundColor: AppColors.brandGreen,
        ),
      );
      Navigator.of(context).pop(ing);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Proponer ingrediente'),
      content: Form(
        key: _formKey,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : _loadError != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _loadError = null;
                          });
                          _loadCategorias();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'El ingrediente solo será visible para ti hasta que el equipo lo apruebe. Después estará disponible para todos.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del ingrediente',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          maxLength: 255,
                          validator: (v) {
                            if ((v?.trim() ?? '').isEmpty) return 'Escribe el nombre';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _categoriaId,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                          ),
                          items: _categorias
                              .map((c) => DropdownMenuItem<int>(
                                    value: c.id,
                                    child: Text(c.nombre),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _categoriaId = v),
                          validator: (v) => v == null ? 'Elige una categoría' : null,
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_loading || _loadError != null || _sending) ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandGreen),
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Proponer'),
        ),
      ],
    );
  }
}
