import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../services/shopping_service.dart';
import '../widgets/cantidad_dialog.dart';

/// Pantalla para elegir un producto y añadirlo a una lista de compra (Crear ítem).
/// Carga productos con búsqueda en servidor (debounce) para no cargar todo el catálogo.
class AddProductoToListaScreen extends StatefulWidget {
  const AddProductoToListaScreen({
    super.key,
    required this.listaId,
  });

  final int listaId;

  @override
  State<AddProductoToListaScreen> createState() => _AddProductoToListaScreenState();
}

class _AddProductoToListaScreenState extends State<AddProductoToListaScreen> {
  static const int _perPage = 100;

  List<ProductoSimple>? _productos;
  String _query = '';
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _currentSearch;
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(search: null);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading || _productos == null) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _currentSearch = search?.trim().isEmpty == true ? null : search;
    });
    try {
      final list = await context.read<ShoppingService>().getProductos(
            q: _currentSearch,
            perPage: _perPage,
            page: 1,
          );
      if (!mounted) return;
      setState(() {
        _productos = list;
        _hasMore = list.length >= _perPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _productos == null) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    try {
      final list = await context.read<ShoppingService>().getProductos(
            q: _currentSearch,
            perPage: _perPage,
            page: nextPage,
          );
      if (!mounted) return;
      setState(() {
        _productos = [..._productos!, ...list];
        _page = nextPage;
        _hasMore = list.length >= _perPage;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final searchText = _searchController.text.trim();
      _load(search: searchText.isEmpty ? null : searchText);
    });
  }

  Future<void> _anadirProducto(ProductoSimple producto) async {
    List<FormatoProveedor> formatos = [];
    List<UnidadMedidaCompleta> unidades = [];
    try {
      final results = await Future.wait([
        context.read<ShoppingService>().getPreciosProveedores(producto.id),
        context.read<ShoppingService>().getUnidadesMedida(),
      ]);
      formatos = results[0] as List<FormatoProveedor>;
      unidades = results[1] as List<UnidadMedidaCompleta>;
    } catch (_) {
      // Si falla, mostramos el diálogo sin formatos y con unidades vacías (se usará fallback)
    }
    if (!mounted) return;

    final result = await showDialog<(double, bool, int?, int?)>(
      context: context,
      builder: (context) => CantidadDialog(
        producto: producto,
        formatos: formatos,
        unidades: unidades,
      ),
    );
    if (result == null || !mounted) return;
    final (cantidad, completado, productoProveedorId, unidadMedidaId) = result;

    try {
      await context.read<ShoppingService>().addItemToLista(
            widget.listaId,
            producto.id,
            cantidad,
            unidadMedidaId: unidadMedidaId ?? producto.unidadMedidaId,
            productoProveedorId: productoProveedorId,
            completado: completado,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto añadido a la lista.'),
          backgroundColor: AppColors.brandGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear ítem'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar',
                hintText: 'Nombre o marca',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error.toString().replaceFirst('Exception: ', '')),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  final t = _searchController.text.trim();
                  _load(search: t.isEmpty ? null : t);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final list = _productos ?? [];
    if (list.isEmpty) {
      return Center(
        child: Text(
          _query.trim().isEmpty
              ? 'No hay productos. Usa el buscador para buscar por nombre o marca.'
              : 'Sin resultados para "$_query".',
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: list.length + (_hasMore && _loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= list.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final p = list[index];
        return ListTile(
          title: Text(p.nombre),
          subtitle: p.marca != null && p.marca!.isNotEmpty
              ? Text(p.marca!)
              : null,
          onTap: () => _anadirProducto(p),
        );
      },
    );
  }
}

