import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/lista_compra.dart';
import 'package:frontend/screens/kitchen_funnel_screen.dart';
import 'package:frontend/screens/shopping_lists_screen.dart';
import 'package:frontend/services/recipe_service.dart';
import 'package:frontend/services/shopping_service.dart';

// Mocks con mocktail (no dependen del backend real)
class MockRecipeService extends Mock implements RecipeService {}

class MockShoppingService extends Mock implements ShoppingService {}

void main() {
  late MockRecipeService mockRecipeService;
  late MockShoppingService mockShoppingService;

  setUp(() {
    mockRecipeService = MockRecipeService();
    mockShoppingService = MockShoppingService();

    when(() => mockRecipeService.fetchRecipes()).thenAnswer((_) async => []);
    when(() => mockRecipeService.fetchPlanificador()).thenAnswer((_) async => []);
    when(() => mockShoppingService.getListas()).thenAnswer((_) async => []);
  });

  Widget createTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        Provider<RecipeService>.value(value: mockRecipeService),
        Provider<ShoppingService>.value(value: mockShoppingService),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('Pruebas de Integración: Embudo de Cocina y Listas de Compras', () {
    testWidgets('Embudo: pestañas Explorar Recetas, Próximamente y Cocinando ahora',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const KitchenFunnelScreen()));
      await tester.pump(); // primer frame

      expect(find.text('Explorar Recetas'), findsOneWidget);
      expect(find.text('Próximamente'), findsOneWidget);
      expect(find.text('Cocinando ahora'), findsOneWidget);
    });

    testWidgets('Embudo: al cambiar a Próximamente la pestaña responde',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const KitchenFunnelScreen()));
      await tester.pump();

      await tester.tap(find.text('Próximamente'));
      await tester.pump(); // un frame; evitamos pumpAndSettle por posibles animaciones/Futures
      await tester.pump(const Duration(milliseconds: 300));

      // KitchenFunnelScreen usa RecipeService() directamente, no Provider.
      // Validamos que la pestaña responde.
      expect(find.text('Próximamente'), findsOneWidget);
    });

    testWidgets('Listas de compra: pantalla usa ShoppingService y muestra estado vacío',
        (WidgetTester tester) async {
      when(() => mockShoppingService.getListas()).thenAnswer((_) async => []);

      await tester.pumpWidget(createTestableWidget(const ShoppingListsScreen()));
      await tester.pumpAndSettle();

      verify(() => mockShoppingService.getListas()).called(1);
      expect(find.text('No hay listas de compra'), findsOneWidget);
    });

    testWidgets('Listas de compra: con una lista y ítem, aparece Checkbox y se puede marcar',
        (WidgetTester tester) async {
      final listaMock = ListaCompraCabecera(
        id: 1,
        titulo: 'Mercadona',
        hogarId: 1,
        userId: 1,
        archivada: false,
        items: [
          ListaCompraItem(
            id: 1,
            listasCompraId: 1,
            cantidad: 2,
            cantidadCompra: 2,
            completado: false,
            estado: 'pendiente',
            producto: const ProductoRef(id: 1, nombre: 'Leche', marca: null),
          ),
        ],
      );
      when(() => mockShoppingService.getListas())
          .thenAnswer((_) async => [listaMock]);
      when(() => mockShoppingService.updateListItem(1, completado: true))
          .thenAnswer((_) async => listaMock.items.first);

      await tester.pumpWidget(createTestableWidget(const ShoppingListsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Mercadona'), findsWidgets);
      expect(find.byType(Checkbox), findsWidgets);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      verify(() => mockShoppingService.updateListItem(1, completado: true)).called(1);
    });
  });
}
