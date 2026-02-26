import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../widgets/chef_planner_logo.dart';
import 'entry_gate.dart';

/// SplashScreen para ChefPlanner.es
/// Paleta: Azul #1B263B, Verde #70E000.
/// Dura 3 segundos y luego navega al flujo principal (EntryGate).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _duration = Duration(seconds: 3);

  double _loadingProgress = 0;
  String _statusText = 'Iniciando cocina...';

  @override
  void initState() {
    super.initState();
    _runProgressSteps();
    _navigateAfterDelay();
  }

  void _runProgressSteps() {
    const steps = [
      (30.0, 'Sincronizando despensa...'),
      (60.0, 'Consultando APIs de supermercados...'),
      (90.0, 'Preparando tu menú semanal...'),
      (100.0, '¡Buen provecho!'),
    ];
    for (var i = 0; i < steps.length; i++) {
      Future.delayed(Duration(milliseconds: (i + 1) * 800), () {
        if (!mounted) return;
        setState(() {
          _loadingProgress = steps[i].$1;
          _statusText = steps[i].$2;
        });
      });
    }
  }

  void _navigateAfterDelay() {
    Future.delayed(_duration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EntryGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBlue,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ChefPlannerLogo(size: 1.0, showTagline: true),
                    const SizedBox(height: 48),
                    _buildProgressBar(),
                    const SizedBox(height: 12),
                    _buildStatusText(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return SizedBox(
      width: 256,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _loadingProgress / 100,
              minHeight: 6,
              backgroundColor: AppColors.brandBlue.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _statusText,
        key: ValueKey<String>(_statusText),
        style: TextStyle(
          color: AppColors.brandWhite.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.calendar,
            size: 16,
            color: AppColors.brandWhite.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            'Organización Total',
            style: TextStyle(
              color: AppColors.brandWhite.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
