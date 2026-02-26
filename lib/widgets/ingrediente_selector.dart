import 'package:flutter/material.dart';

import '../models/recipe.dart';

/// Campo que al pulsar abre un modal con buscador por texto para elegir un ingrediente.
/// Útil cuando la lista de ingredientes es muy larga.
class IngredienteSelector extends StatelessWidget {
  const IngredienteSelector({
    super.key,
    required this.ingredientes,
    required this.value,
    required this.onChanged,
    this.decoration,
    this.enabled = true,
  });

  final List<Ingredient> ingredientes;
  final int? value;
  final ValueChanged<int?> onChanged;
  final InputDecoration? decoration;
  final bool enabled;

  String get _labelSelected {
    if (value == null) return '';
    final idx = ingredientes.indexWhere((i) => i.id == value);
    return idx >= 0 ? ingredientes[idx].nombre : '';
  }

  void _openSelector(BuildContext context) {
    if (!enabled) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _IngredienteSearchSheet(
        ingredientes: ingredientes,
        selectedId: value,
        onSelect: (id) {
          Navigator.of(ctx).pop();
          onChanged(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decoration = this.decoration ?? const InputDecoration(
      labelText: 'Ingrediente',
      border: OutlineInputBorder(),
      isDense: true,
    );
    return InkWell(
      onTap: () => _openSelector(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: decoration.copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down),
          errorText: null,
        ),
        isEmpty: value == null,
        child: Text(
          _labelSelected,
          style: value == null
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  )
              : null,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _IngredienteSearchSheet extends StatefulWidget {
  const _IngredienteSearchSheet({
    required this.ingredientes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Ingredient> ingredientes;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  @override
  State<_IngredienteSearchSheet> createState() => _IngredienteSearchSheetState();
}

class _IngredienteSearchSheetState extends State<_IngredienteSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Ingredient> get _filtered {
    if (_query.isEmpty) return widget.ingredientes;
    return widget.ingredientes
        .where((i) => i.nombre.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar ingrediente...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty ? 'No hay ingredientes' : 'Sin resultados para "$_query"',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final ing = filtered[index];
                        final selected = ing.id == widget.selectedId;
                        return ListTile(
                          title: Text(ing.nombre),
                          trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
                          onTap: () => widget.onSelect(ing.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
