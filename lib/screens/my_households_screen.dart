import 'package:flutter/material.dart';

import '../models/hogar.dart';
import '../theme/app_colors.dart';
import '../services/hogar_service.dart';
import '../widgets/main_layout.dart';
import 'home_setup_screen.dart';
import 'recipe_list_screen.dart';

class MyHouseholdsScreen extends StatefulWidget {
  const MyHouseholdsScreen({super.key});

  @override
  State<MyHouseholdsScreen> createState() => _MyHouseholdsScreenState();
}

class _MyHouseholdsScreenState extends State<MyHouseholdsScreen> {
  late Future<HogaresResult> _future;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _future = HogarService().fetchHogares();
    hogaresDataChangedNotifier.addListener(_onHogaresDataChanged);
  }

  @override
  void dispose() {
    hogaresDataChangedNotifier.removeListener(_onHogaresDataChanged);
    super.dispose();
  }

  void _onHogaresDataChanged() {
    if (mounted) {
      setState(() => _future = HogarService().fetchHogares());
    }
  }

  Future<void> _setActive(int hogarId) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await HogarService().setHogarActivo(hogarId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RecipeListScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Mis Hogares',
      child: FutureBuilder<HogaresResult>(
        future: _future,
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

          final data = snapshot.data;
          final hogares = data?.hogares ?? <Hogar>[];
          final hogarActivoId = data?.hogarActivoId;

          if (hogares.isEmpty) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HomeSetupScreen()),
                  );
                },
                child: const Text('Unirme o crear un hogar'),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const HomeSetupScreen()),
                            );
                          },
                    child: const Text('Añadir hogar'),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: hogares.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final hogar = hogares[index];
                    final isActive = hogarActivoId == hogar.id;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isActive ? AppColors.brandGreen : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.home, color: isActive ? AppColors.brandGreen : null),
                        title: Text(hogar.nombre),
                        subtitle: hogar.esPrincipal ? const Text('Principal') : null,
                        trailing: isActive
                            ? const Icon(Icons.check_circle, color: AppColors.brandGreen)
                            : null,
                        onTap: _isSubmitting ? null : () => _setActive(hogar.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
