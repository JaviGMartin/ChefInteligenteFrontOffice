import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/hogar_service.dart';
import '../widgets/app_drawer.dart';
import 'recipe_list_screen.dart';

class HomeSetupScreen extends StatefulWidget {
  const HomeSetupScreen({super.key});

  @override
  State<HomeSetupScreen> createState() => _HomeSetupScreenState();
}

class _HomeSetupScreenState extends State<HomeSetupScreen> {
  final _createKey = GlobalKey<FormState>();
  final _joinKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createHogar() async {
    if (!_createKey.currentState!.validate()) {
      return;
    }
    await _submit(() async {
      await HogarService().crearHogar(
        nombre: _nameController.text.trim(),
        telefono: _phoneController.text.trim(),
      );
    });
  }

  Future<void> _joinHogar() async {
    if (!_joinKey.currentState!.validate()) {
      return;
    }
    await _submit(() => HogarService().unirseAHogar(_codeController.text.trim()));
  }

  Future<void> _submit(Future<void> Function() action) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RecipeListScreen()),
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
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar hogar')),
      drawer: const AppDrawer(),
      body: StainlessBackground(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: cardShape,
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _createKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crear mi Hogar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del hogar',
                        hintText: 'Casa de Javi',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es obligatorio.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (opcional)',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _createHogar,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Crear hogar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: cardShape,
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _joinKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tengo un código',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Codigo de invitacion',
                        hintText: 'ABC123',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El codigo es obligatorio.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : _joinHogar,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Unirme'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
