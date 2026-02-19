import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/family_data.dart';
import '../models/hogar_equipo.dart';
import '../models/intolerancia.dart';
import '../screens/households_management_screen.dart';
import '../screens/member_profile_screen.dart';
import '../services/hogar_service.dart';
import '../widgets/main_layout.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  late Future<HogarEquipo?> _future;
  int? _hogarId;
  String? _hogarNombre;
  bool _isSubmitting = false;
  InvitacionesData? _invitacionesData;
  bool _invitacionesLoading = false;
  bool _invitacionesLoadRequested = false;
  final TextEditingController _codigoUnirseController = TextEditingController();
  bool _joinSubmitting = false;

  @override
  void initState() {
    super.initState();
    _future = _loadEquipo();
    hogarActivoIdNotifier.addListener(_onHogarActivoChanged);
  }

  @override
  void dispose() {
    hogarActivoIdNotifier.removeListener(_onHogarActivoChanged);
    _codigoUnirseController.dispose();
    super.dispose();
  }

  void _onHogarActivoChanged() {
    if (mounted) _refresh();
  }

  Future<HogarEquipo?> _loadEquipo() async {
    final hogarId = await HogarService().getHogarIdActual();
    if (mounted) {
      setState(() {
        _hogarId = hogarId;
      });
    }
    if (hogarId == null) {
      return null;
    }
    try {
      final data = await HogarService().fetchEquipo(hogarId);
      if (mounted) {
        setState(() {
          _hogarNombre = data.hogarNombre;
        });
      }
      return data;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('403') || msg.contains('forbidden')) {
        await HogarService().clearHogarActivo();
        if (mounted) {
          setState(() {
            _hogarId = null;
            _hogarNombre = null;
          });
        }
      }
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadEquipo();
      _invitacionesData = null;
      _invitacionesLoadRequested = false;
    });
  }

  Future<void> _loadInvitaciones() async {
    if (_hogarId == null || _invitacionesLoading) return;
    setState(() => _invitacionesLoading = true);
    try {
      final d = await HogarService().fetchInvitaciones(_hogarId!);
      if (mounted) setState(() => _invitacionesData = d);
    } catch (_) {
      if (mounted) setState(() => _invitacionesData = null);
    } finally {
      if (mounted) setState(() => _invitacionesLoading = false);
    }
  }

  Future<void> _unirseConCodigo() async {
    final codigo = _codigoUnirseController.text.trim().toUpperCase();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce el código de invitación que te han compartido.'),
        ),
      );
      return;
    }
    setState(() => _joinSubmitting = true);
    try {
      await HogarService().unirseAHogar(codigo);
      _codigoUnirseController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te has unido al hogar. Ya está activo.'),
          backgroundColor: Color(0xFF00914E),
        ),
      );
      await _refresh();
      // El panel se cierra solo: al cambiar _hogarId, el ExpansionTile se reconstruye con initiallyExpanded: false (key distinto).
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _joinSubmitting = false);
    }
  }

  Widget _buildUnirseAHogarCard() {
    // Sin hogar: abierto por defecto para guiar; con hogar: cerrado. Tras unirse, el key cambia y se reconstruye cerrado.
    final initiallyOpen = _hogarId == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: ExpansionTile(
          key: ValueKey('unirse_hogar_${_hogarId ?? 0}'),
          initiallyExpanded: initiallyOpen,
          leading: Icon(Icons.add_home, color: Theme.of(context).colorScheme.primary),
          title: Text(
            'Unirse a otro hogar con código',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Si te han compartido un código de invitación, introdúcelo aquí para unirte al hogar.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codigoUnirseController,
                          decoration: const InputDecoration(
                            labelText: 'Código',
                            hintText: 'Ej: ABC123',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 10,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _joinSubmitting ? null : _unirseConCodigo,
                        child: _joinSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Unirme'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarCodigo() async {
    if (_hogarId == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final codigo = await HogarService().generarInvitacion(_hogarId!);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Código de invitación'),
          content: SelectableText(codigo),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: codigo));
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado')),
                );
              },
              child: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      if (mounted) await _loadInvitaciones();
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

  void _showAddBottomSheet() {
    if (_hogarId == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Invitar con código'),
              onTap: () {
                Navigator.of(ctx).pop();
                _generarCodigo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Crear familiar (sin cuenta)'),
              onTap: () {
                Navigator.of(ctx).pop();
                _addMiembroSinCuenta();
              },
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom),
              title: const Text('Añadir desde Mi Familia'),
              onTap: () {
                Navigator.of(ctx).pop();
                _anadirDesdeMiFamilia();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _anadirDesdeMiFamilia() async {
    if (_hogarId == null) return;
    try {
      final family = await HogarService().fetchMisDependientes();
      final equipo = await HogarService().fetchEquipo(_hogarId!);
      final idsEnEquipo = equipo.miembros.map((m) => m.id).toSet();
      final disponibles = family.dependientes
          .where((d) => !idsEnEquipo.contains(d.id))
          .toList();
      if (!mounted) return;
      if (disponibles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Todos tus familiares ya están en este hogar, o no tienes dependientes. Añade familiares en Mi Familia.',
            ),
          ),
        );
        return;
      }
      // Resultado: null = cancelar, 'deleted' = se eliminó un dependiente (refrescar), HogarMember = seleccionado para vincular
      final selected = await showDialog<Object>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Añadir desde Mi Familia'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: disponibles.length,
              itemBuilder: (context, index) {
                final m = disponibles[index];
                return ListTile(
                  title: Text(m.name),
                  subtitle: Text(m.edad != null ? '${m.edad} años' : ''),
                  onTap: () => Navigator.of(ctx).pop(m),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Eliminar de forma permanente',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (c) => AlertDialog(
                          title: const Text('¿Eliminar dependiente?'),
                          content: const Text(
                            'Esta acción es irreversible y eliminará el perfil de todo el sistema.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(c).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.of(c).pop(true),
                              child: const Text('Eliminar definitivamente'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true || !ctx.mounted) return;
                      try {
                        await HogarService().eliminarDependiente(m.id);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop('deleted');
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      if (selected == 'deleted') {
        _refresh();
        return;
      }
      final member = selected as HogarMember;
      await HogarService().vincularDependienteAHogar(
        hogarId: _hogarId!,
        userId: member.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} añadido al hogar')),
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addMiembroSinCuenta() async {
    if (_hogarId == null) return;
    final nameController = TextEditingController();
    DateTime? birthDate;
    String? birthDateStr;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Crear familiar (sin cuenta)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Ej: María, Niño',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fecha de nacimiento (opcional)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          locale: const Locale('es', 'ES'),
                        );
                        if (picked != null && context.mounted) {
                          setState(() {
                            birthDate = picked;
                            birthDateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        birthDateStr ?? 'Seleccionar fecha',
                        style: TextStyle(
                          color: birthDateStr != null
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                    if (birthDateStr != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Las intolerancias se editan después desde la ficha del miembro.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
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
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Indica el nombre')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    try {
                      await HogarService().addMiembroSinCuenta(
                        hogarId: _hogarId!,
                        name: name,
                        birthDate: birthDateStr,
                      );
                      await _refresh();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$name añadido al hogar')),
                        );
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _expulsarMiembro(HogarMember member) async {
    if (_hogarId == null) return;
    final esDependiente = member.email == null || member.email!.isEmpty;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esDependiente ? '¿Qué hacer con ${member.name}?' : 'Expulsar del equipo'),
        content: Text(
          esDependiente
              ? 'Puedes solo quitar del hogar (seguirá en tu familia) o eliminar de forma permanente del sistema.'
              : '¿Expulsar a ${member.name} del hogar? Ya no tendrá acceso al equipo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('quitar'),
            child: Text(esDependiente ? 'Solo quitar del hogar' : 'Expulsar'),
          ),
          if (esDependiente)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('eliminar'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar permanentemente'),
            ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'eliminar') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Eliminar de forma permanente?'),
          content: const Text(
            'Esta acción es irreversible y eliminará el perfil de todo el sistema.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      setState(() => _isSubmitting = true);
      try {
        await HogarService().eliminarDependiente(member.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dependiente eliminado del sistema')),
        );
        await _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await HogarService().expulsarMiembro(hogarId: _hogarId!, userId: member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miembro quitado del hogar')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _editarIntolerancias(HogarMember member) async {
    if (_hogarId == null) {
      return;
    }
    final all = await HogarService().fetchIntolerancias();
    final selected = member.intolerancias.map((i) => i.id).toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Intolerancias de ${member.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: all.map((item) {
                    final isSelected = selected.contains(item.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(item.nombre),
                      activeColor: const Color(0xFF00914E),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(item.id);
                          } else {
                            selected.remove(item.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await HogarService().updateIntolerancias(
                      hogarId: _hogarId!,
                      memberId: member.id,
                      intoleranciasIds: selected.toList(),
                    );
                    await _refresh();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editarNotas(HogarMember member) async {
    if (_hogarId == null) return;
    print('VALOR INICIAL NOTA: ${member.notas}');
    final controller = TextEditingController(text: member.notas ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Notas de ${member.name}'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'Notas para este hogar (opcional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await HogarService().updateNotasMiembro(
                    hogarId: _hogarId!,
                    userId: member.id,
                    notas: controller.text.trim().isEmpty ? null : controller.text.trim(),
                  );
                  await _refresh();
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.toString())),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  static const Color _accent = Color(0xFF00914E);
  static const Color _ownerGold = Color(0xFFD4AF37);
  static const List<Color> _intoleranceChipColors = [
    Color(0xFFFF8A65), // deepOrange 300
    Color(0xFFFFB74D), // orange 300
    Color(0xFFA1887F), // brown 300
    Color(0xFF81C784), // green 300
    Color(0xFF64B5F6), // blue 300
    Color(0xFFBA68C8), // purple 300
  ];

  Widget _buildInvitacionesSection(
      BuildContext context, HogarEquipo data) {
    final inv = _invitacionesData;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Códigos de Invitación Activos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (_invitacionesLoading || (inv == null && _invitacionesLoadRequested))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (inv != null) ...[
            Text(
              inv.textoContador,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 12),
            if (inv.invitaciones.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No hay códigos activos. Genera uno desde el menú Añadir.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else
              ...inv.invitaciones.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            item.codigo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: item.codigo),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código copiado'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copiar'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  final confirm =
                                      await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text(
                                        '¿Eliminar código?',
                                      ),
                                      content: const Text(
                                        'El código dejará de ser válido.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true ||
                                      _hogarId == null ||
                                      !mounted) return;
                                  setState(() => _isSubmitting = true);
                                  try {
                                    await HogarService().eliminarInvitacion(
                                      hogarId: _hogarId!,
                                      invitacionId: item.id,
                                    );
                                    if (mounted) {
                                      _invitacionesData = null;
                                      _invitacionesLoadRequested = false;
                                      await _loadInvitaciones();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Código eliminado'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('$e')),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isSubmitting = false);
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberCard(HogarEquipo data, HogarMember member, int memberIndex) {
    final isOwner = member.esPropietario;
    final subtitle = member.email == null ? 'Sin cuenta' : member.email!;
    final canEdit = data.isOwner || member.id == data.currentUserId;
    final canExpel = data.isOwner &&
        !member.esPropietario &&
        member.id != data.currentUserId;

    return InkWell(
      onTap: () {
        if (_hogarId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemberProfileScreen(
              member: member,
              hogarId: _hogarId!,
              isOwner: data.isOwner,
              currentUserId: data.currentUserId,
            ),
          ),
        ).then((_) => _refresh());
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: isOwner ? 3 : 2,
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOwner ? _ownerGold : _accent,
          width: isOwner ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isOwner ? _ownerGold.withOpacity(0.2) : _accent.withOpacity(0.15),
                  backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(member.avatarUrl!)
                      : null,
                  onBackgroundImageError: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                      ? (_, __) {}
                      : null,
                  child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                      ? Text(
                          member.name.isNotEmpty ? member.name.trim().toUpperCase()[0] : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isOwner ? _ownerGold : _accent,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isOwner) ...[
                            Icon(Icons.workspace_premium, size: 18, color: _ownerGold),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              member.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOwner
                        ? _ownerGold.withOpacity(0.15)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOwner ? _ownerGold : Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isOwner ? 'PROPIETARIO' : 'MIEMBRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isOwner ? _ownerGold : Colors.blue.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (member.intolerancias.isNotEmpty) ...[
              Text(
                'Restricciones alimentarias',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: member.intolerancias.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final chipColor = _intoleranceChipColors[i % _intoleranceChipColors.length];
                  return Chip(
                    avatar: Icon(Icons.warning_amber_rounded, size: 16, color: chipColor),
                    label: Text(
                      item.nombre,
                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    backgroundColor: chipColor.withOpacity(0.22),
                    side: BorderSide(color: chipColor.withOpacity(0.7), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (member.notas != null && member.notas!.isNotEmpty) ...[
              Text(
                'Notas',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  member.notas!,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: canEdit ? () => _editarNotas(member) : null,
                  child: const Text('Editar notas'),
                ),
                TextButton(
                  onPressed: canEdit ? () => _editarIntolerancias(member) : null,
                  child: const Text('Editar intolerancias'),
                ),
                if (canExpel)
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _expulsarMiembro(member),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Expulsar'),
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _hogarNombre != null && _hogarNombre!.isNotEmpty
        ? 'Equipo: $_hogarNombre'
        : 'Mi Equipo';
    return MainLayout(
      title: title,
      child: FutureBuilder<HogarEquipo?>(
        future: _future,
        builder: (context, snapshot) {
          // Cajetín "Unirse a un hogar" SIEMPRE visible arriba (evita bloqueo al navegar atrás o sin hogar).
          Widget contentBelow;
          if (snapshot.connectionState == ConnectionState.waiting) {
            contentBelow = const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            contentBelow = Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _refresh, child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          } else {
            final data = snapshot.data;
            if (data == null) {
              // Estado vacío: mensaje e "Ir a Mis Casas" DEBAJO del cajetín de unión.
              contentBelow = Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_work, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Primero crea o selecciona un Hogar',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Para gestionar a tu equipo y añadir miembros, necesitas un hogar activo. Puedes unirte con un código arriba o ir a Mis Casas.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const HouseholdsManagementScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.home_work, size: 20),
                        label: const Text('Ir a Mis Casas'),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              // Con datos: lista de miembros (y códigos). Se devuelve más abajo en un Column con Unirse + este contenido.
              contentBelow = _buildEquipoContent(data);
            }
          }

          final data = snapshot.data;
          if (data != null) {
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildUnirseAHogarCard(),
                    Expanded(child: contentBelow),
                  ],
                ),
                if (data.isOwner && !_isSubmitting && !data.alLimiteDeMiembros)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      onPressed: _showAddBottomSheet,
                      child: const Icon(Icons.add),
                    ),
                  ),
              ],
            );
          }

          // Sin datos (loading, error o estado vacío): Unirse arriba + contenido debajo.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUnirseAHogarCard(),
              Expanded(child: contentBelow),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEquipoContent(HogarEquipo data) {
    final atLimit = data.alLimiteDeMiembros;
    final count = data.miembros.length;
    final maxCount = data.limiteMiembros;
    final onlyOwnerInList = count == 1 && data.miembros.first.esPropietario;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    maxCount != null
                        ? 'Miembros: $count / $maxCount'
                        : 'Miembros: $count',
                    style: TextStyle(
                      fontSize: 14,
                      color: atLimit ? Colors.orange.shade800 : Colors.black87,
                      fontWeight: atLimit ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (maxCount != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxCount! > 0 ? count / maxCount : 0,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            atLimit ? Colors.orange : _accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: data.miembros.length +
                (onlyOwnerInList ? 1 : 0) +
                (data.isOwner ? 1 : 0),
            itemBuilder: (context, index) {
              final codesSectionIndex =
                  data.miembros.length + (onlyOwnerInList ? 1 : 0);
              if (data.isOwner && index == codesSectionIndex) {
                if (!_invitacionesLoadRequested) {
                  _invitacionesLoadRequested = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _loadInvitaciones();
                  });
                }
                return _buildInvitacionesSection(context, data);
              }
              if (onlyOwnerInList && index == 1) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.group_add, size: 40, color: Colors.grey.shade400),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Parece que estás solo en este hogar. ¡Genera un código e invita a tu familia o compañeros!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final member = data.miembros[index];
              return _buildMemberCard(data, member, index);
            },
          ),
        ),
      ],
    );
  }
}
