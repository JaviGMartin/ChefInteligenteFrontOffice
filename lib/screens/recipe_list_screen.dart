import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_service.dart';

class RecipeListScreen extends StatelessWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetas'),
      ),
      body: FutureBuilder<List<Recipe>>(
        future: RecipeService().fetchRecipes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
              ),
            );
          }

          final recipes = snapshot.data ?? [];
          if (recipes.isEmpty) {
            return const Center(child: Text('No hay recetas.'));
          }

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return ListTile(
                title: Text(recipe.titulo),
                subtitle: Text(
                  recipe.averageRating != null
                      ? 'Rating: ${recipe.averageRating}'
                      : 'Rating: —',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
