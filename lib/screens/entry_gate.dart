import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import 'app_start_screen.dart';
import 'login_screen.dart';
import 'recipe_list_screen.dart';

/// Pantalla que decide si mostrar Login o AppStart según token.
/// Si la app se abrió por deep link de voz (chefplanner://app/recipes), con token navega a RecipeListScreen.
class EntryGate extends StatelessWidget {
  const EntryGate({super.key});

  static const _timeout = Duration(seconds: 4);

  Future<(bool hasToken, Uri? initialUri)> _resolveGate() async {
    final prefs = await SharedPreferences.getInstance().timeout(_timeout);
    final token = prefs.getString('auth_token');
    final hasToken = token != null && token.isNotEmpty;
    Uri? initialUri;
    try {
      initialUri = await AppLinks().getInitialLink();
    } catch (_) {}
    return (hasToken, initialUri);
  }

  static bool _isRecipesDeepLink(Uri? uri) {
    if (uri == null) return false;
    return uri.scheme == 'chefplanner' && uri.pathSegments.contains('recipes');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(bool hasToken, Uri? initialUri)>(
      future: _resolveGate(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.brandBlue,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.chefHat,
                    size: 80,
                    color: AppColors.brandWhite,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: AppColors.brandGreen),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.brandWhite,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final hasToken = snapshot.hasError ? false : (snapshot.data?.$1 ?? false);
        final initialUri = snapshot.data?.$2;

        if (hasToken && _isRecipesDeepLink(initialUri)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RecipeListScreen()),
            );
          });
          return const Scaffold(
            backgroundColor: AppColors.brandBlue,
            body: Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
          );
        }

        return hasToken ? const AppStartScreen() : const LoginScreen();
      },
    );
  }
}
