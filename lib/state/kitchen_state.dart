import 'package:flutter/foundation.dart';

import '../models/pendiente_compra.dart';
import '../models/recipe.dart';
import '../services/hogar_service.dart';
import '../services/recipe_service.dart';
import '../services/shopping_service.dart';

/// Estado global del flujo Cocina → Embudo → Compras.
/// Centraliza planificador (recetas con semáforos) y pendientes (embudo).
/// Al marcar una compra como procesada, se debe llamar [refreshAfterPurchase]
/// para actualizar semáforos.
class KitchenState extends ChangeNotifier {
  KitchenState() {
    hogarActivoIdNotifier.addListener(_onHogarActivoChanged);
  }

  final RecipeService _recipeService = RecipeService();
  final ShoppingService _shoppingService = ShoppingService();

  List<Recipe>? _planificadorRecipes;
  List<PendienteCompra>? _shoppingPendientes;
  bool _isLoadingPlanificador = false;
  bool _isLoadingPendientes = false;
  Object? _planificadorError;
  Object? _pendientesError;

  List<Recipe>? get planificadorRecipes => _planificadorRecipes;
  List<PendienteCompra>? get shoppingPendientes => _shoppingPendientes;
  bool get isLoadingPlanificador => _isLoadingPlanificador;
  bool get isLoadingPendientes => _isLoadingPendientes;
  Object? get planificadorError => _planificadorError;
  Object? get pendientesError => _pendientesError;

  void _onHogarActivoChanged() {
    loadPlanificador();
    loadPendientes();
  }

  /// Carga las recetas del planificador (con semáforos). Llamar al entrar en Cocina.
  Future<void> loadPlanificador() async {
    _isLoadingPlanificador = true;
    _planificadorError = null;
    notifyListeners();
    try {
      _planificadorRecipes = await _recipeService.fetchPlanificador();
    } catch (e) {
      _planificadorError = e;
      _planificadorRecipes = [];
    } finally {
      _isLoadingPlanificador = false;
      notifyListeners();
    }
  }

  /// Carga los pendientes del embudo.
  Future<void> loadPendientes() async {
    _isLoadingPendientes = true;
    _pendientesError = null;
    notifyListeners();
    try {
      _shoppingPendientes = await _shoppingService.getPendientes();
    } catch (e) {
      _pendientesError = e;
      _shoppingPendientes = [];
    } finally {
      _isLoadingPendientes = false;
      notifyListeners();
    }
  }

  /// Llamar tras "Procesar compra" para actualizar semáforos y pendientes.
  void refreshAfterPurchase() {
    loadPlanificador();
    loadPendientes();
  }

  @override
  void dispose() {
    hogarActivoIdNotifier.removeListener(_onHogarActivoChanged);
    super.dispose();
  }
}
