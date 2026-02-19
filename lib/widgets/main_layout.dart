import 'package:flutter/material.dart';

import 'app_drawer.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        leading: canPop ? BackButton(color: primary) : null,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: Text(title),
        actions: actions,
      ),
      drawer: const AppDrawer(),
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }
}
