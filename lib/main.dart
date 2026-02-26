import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/alarma_notification_service.dart';
import 'services/shopping_service.dart';
import 'state/kitchen_state.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmaNotificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ShoppingService>(create: (_) => ShoppingService()),
        ChangeNotifierProvider<KitchenState>(create: (_) => KitchenState()),
      ],
      child: MaterialApp(
      title: 'ChefPlanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandBlue,
          brightness: Brightness.light,
          primary: AppColors.brandBlue,
          onPrimary: AppColors.brandWhite,
          surface: AppColors.stainlessLight,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.stainlessLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.brandBlue,
          foregroundColor: AppColors.brandWhite,
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.brandWhite,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    ),
    );
  }
}
