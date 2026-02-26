import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: canPop ? const BackButton(color: AppColors.brandWhite) : null,
        iconTheme: const IconThemeData(color: AppColors.brandWhite),
        titleTextStyle: const TextStyle(
          color: AppColors.brandWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: Text(title),
        backgroundColor: AppColors.brandBlue,
        foregroundColor: AppColors.brandWhite,
        actions: actions,
      ),
      drawer: const AppDrawer(),
      body: StainlessBackground(child: child),
      floatingActionButton: floatingActionButton,
    );
  }
}
