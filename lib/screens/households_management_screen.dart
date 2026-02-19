import 'package:flutter/material.dart';

import '../models/hogar.dart';
import '../services/auth_service.dart';
import '../services/hogar_service.dart';
import '../screens/household_detail_screen.dart';
import '../widgets/main_layout.dart';

class HouseholdsManagementScreen extends StatefulWidget {
  const HouseholdsManagementScreen({super.key});

  @override
  State<HouseholdsManagementScreen> createState() => _HouseholdsManagementScreenState();
}

class _HouseholdsManagementScreenState extends State<HouseholdsManagementScreen> {
  late Future<HogaresResult> _future;
  int? _hogarActivoId;
  List<Hogar> _hogares = [];

  @override
  void initState() {
    super.initState();
    _future = HogarService().fetchHogares();
    AuthService().fetchUser(forceRefresh: true);
    hogaresDataChangedNotifier.addListener(_onHogaresDataChanged);
  }

  @override
  void dispose() {
    hogaresDataChangedNotifier.removeListener(_onHogaresDataChanged);
    super.dispose();
  }

  void _onHogaresDataChanged() {
    if (mounted) _refreshHouseholds();
  }

  void _refreshHouseholds() {
    setState(() {
      _future = HogarService().fetchHogares();
    });
  }

  Future<void> _openCreateHogarSheet(bool canCreate) async {
    if (!canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actualiza tu plan para tener múltiples hogares.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final direccionController = TextEditingController();
    final telefonoController = TextEditingController();
    bool setPrincipal = true;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Nuevo hogar', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre del hogar'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: direccionController,
                    decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: telefonoController,
                    decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Establecer como principal'),
                    value: setPrincipal,
                    onChanged: (value) {
                      setState(() {
                        setPrincipal = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final nombre = nameController.text.trim();
                        if (nombre.isEmpty) {
                          return;
                        }
                        try {
                          final hogarId = await HogarService().crearHogar(
                            nombre: nombre,
                            direccion: direccionController.text.trim(),
                            telefono: telefonoController.text.trim(),
                            esPrincipal: setPrincipal,
                          );
                          if (hogarId != null && setPrincipal) {
                            await HogarService().setHogarPrincipal(hogarId);
                            await AuthService().updateHogarActivo(nombre);
                          }
                          await AuthService().fetchUser(forceRefresh: true);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hogar creado')),
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                      child: const Text('Crear'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );

    if (created == true) {
      _refreshHouseholds();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Hogares',
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
          _hogares = hogares;
          _hogarActivoId = data?.hogarActivoId;

          if (hogares.isEmpty) {
            return const Center(child: Text('No hay hogares disponibles.'));
          }

          return ListView.builder(
            itemCount: hogares.length,
            itemBuilder: (context, index) {
              final hogar = hogares[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(hogar.nombre),
                  subtitle: hogar.esPrincipal ? const Text('Principal') : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context)
                        .push<bool>(
                      MaterialPageRoute(
                        builder: (_) => HouseholdDetailScreen(hogar: hogar),
                      ),
                    )
                        .then((_) => _refreshHouseholds());
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<AuthUser?>(
        valueListenable: AuthService.userNotifier,
        builder: (context, user, _) {
          final role = user?.role?.toLowerCase();
          final isFree = role == 'gratis' || role == 'free';
          final canCreate = !(isFree && _hogares.isNotEmpty);
          final primary = Theme.of(context).colorScheme.primary;
          return FloatingActionButton(
            backgroundColor: primary,
            onPressed: () => _openCreateHogarSheet(canCreate),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
