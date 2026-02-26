import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/family_data.dart';
import '../models/hogar_equipo.dart';
import '../screens/member_profile_screen.dart';
import '../services/hogar_service.dart';
import '../theme/app_colors.dart';
import '../widgets/main_layout.dart';

const Color _accent = AppColors.brandGreen;

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  late Future<FamilyData> _future;
  int? _hogarId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<FamilyData> _load() async {
    _hogarId = await HogarService().getHogarIdActual();
    return HogarService().fetchMisDependientes();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  void _openProfile(HogarMember member, FamilyData data) async {
    final hogarId = _hogarId;
    if (hogarId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un hogar activo en Hogares para editar el perfil en contexto.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MemberProfileScreen(
          member: member,
          hogarId: hogarId,
          isOwner: true,
          currentUserId: data.tutor.id,
        ),
      ),
    );
    if (!mounted) return;
    _refresh();
  }

  Future<void> _anadirFamiliar() async {
    final nameController = TextEditingController();
    DateTime? birthDate;
    final birthDateController = TextEditingController();
    final screenContext = context;

    String formatDate(DateTime d) {
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      return '$day/$month/${d.year}';
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Añadir familiar'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fecha de nacimiento (opcional)',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: birthDateController,
                      readOnly: true,
                      onTap: () async {
                        final initial = birthDate ?? DateTime(DateTime.now().year - 20);
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: initial,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          helpText: 'Fecha de nacimiento',
                        );
                        if (picked != null) {
                          setDialogState(() {
                            birthDate = picked;
                            birthDateController.text = formatDate(picked!);
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'dd/mm/aaaa',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('El nombre es obligatorio')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    try {
                      final birthDateStr = birthDate != null
                          ? '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}'
                          : null;
                      await HogarService().crearDependiente(
                        name: name,
                        birthDate: birthDateStr,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        const SnackBar(content: Text('Familiar añadido')),
                      );
                      _refresh();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(screenContext).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Mi Familia',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _anadirFamiliar,
        icon: const Icon(Icons.person_add),
        label: const Text('Añadir familiar'),
        backgroundColor: _accent,
      ),
      child: FutureBuilder<FamilyData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No hay datos'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mi perfil',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                _MemberCard(
                  member: data.tutor,
                  subtitle: data.tutor.email ?? 'Titular',
                  isTutor: true,
                  onTap: () => _openProfile(data.tutor, data),
                ),
                const SizedBox(height: 24),
                Text(
                  'Mis dependientes',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                if (data.dependientes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Aún no tienes familiares añadidos. Pulsa "Añadir familiar" para crear un perfil.',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...data.dependientes.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MemberCard(
                        member: m,
                        subtitle: m.edad != null ? '${m.edad} años' : '—',
                        isTutor: false,
                        onTap: () => _openProfile(m, data),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final HogarMember member;
  final String subtitle;
  final bool isTutor;
  final VoidCallback onTap;

  const _MemberCard({
    required this.member,
    required this.subtitle,
    required this.isTutor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isNotEmpty ? member.name.trim().toUpperCase()[0] : '?';
    final hasAvatar = member.avatarUrl != null && member.avatarUrl!.isNotEmpty;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _accent.withOpacity(0.15),
                backgroundImage: hasAvatar ? CachedNetworkImageProvider(member.avatarUrl!) : null,
                onBackgroundImageError: hasAvatar ? (_, __) {} : null,
                child: hasAvatar
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _accent,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isTutor)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tú',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}
