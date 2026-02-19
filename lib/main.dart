import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/app_start_screen.dart';
import 'screens/login_screen.dart';
import 'services/alarma_notification_service.dart';
import 'services/shopping_service.dart';
import 'state/kitchen_state.dart';

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
      title: 'App Cocina',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00914E)),
        useMaterial3: true,
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
      home: const EntryGate(),
    ),
    );
  }
}

class EntryGate extends StatelessWidget {
  const EntryGate({super.key});

  Future<bool> _hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final hasToken = snapshot.data ?? false;
        return hasToken ? const AppStartScreen() : const LoginScreen();
      },
    );
  }
}
