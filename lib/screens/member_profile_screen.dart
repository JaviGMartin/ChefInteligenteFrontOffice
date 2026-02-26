import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/hogar_equipo.dart';
import '../models/intolerancia.dart';
import '../services/hogar_service.dart';
import '../theme/app_colors.dart';
import '../widgets/main_layout.dart';

class MemberProfileScreen extends StatefulWidget {
  final HogarMember member;
  final int hogarId;
  final bool isOwner;
  final int currentUserId;

  const MemberProfileScreen({
    super.key,
    required this.member,
    required this.hogarId,
    required this.isOwner,
    required this.currentUserId,
  });

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  static const Color _accent = AppColors.brandGreen;
  static const Color _ownerGold = Color(0xFFD4AF37);
  late TextEditingController _nameController;
  late TextEditingController _birthDateController;
  late TextEditingController _notasController;
  DateTime? _birthDate;
  String? _avatarUrl;
  List<Intolerancia> _intolerancias = [];
  bool _saving = false;
  final ImagePicker _imagePicker = ImagePicker();

  static String _formatBirthDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  static String _birthDateToApi(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.name);
    _birthDate = _parseBirthDate(widget.member.birthDate);
    _birthDateController = TextEditingController(
      text: _birthDate != null ? _formatBirthDate(_birthDate!) : '',
    );
    _notasController = TextEditingController(text: widget.member.notas ?? '');
    _avatarUrl = widget.member.avatarUrl;
    _intolerancias = List.from(widget.member.intolerancias);
  }

  DateTime? _parseBirthDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  bool get _canEditNotesAndIntolerances =>
      widget.isOwner || widget.member.id == widget.currentUserId;
  bool get _canEditFullProfile =>
      widget.member.esFicticio && widget.isOwner;

  Future<void> _pickAndUploadAvatar() async {
    if (!_canEditFullProfile) return;
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Cámara'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;

      final XFile? xFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xFile == null || !mounted) return;

      final Uint8List bytes = await xFile.readAsBytes();
      final String filename = xFile.name.isNotEmpty ? xFile.name : 'avatar.jpg';
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo foto...')),
      );
      setState(() => _saving = true );

      final newUrl = await HogarService().uploadAvatarMiembro(
        hogarId: widget.hogarId,
        userId: widget.member.id,
        bytes: bytes,
        filename: filename,
      );

      if (!mounted) return;
      setState(() {
        _avatarUrl = newUrl;
        _saving = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto actualizada')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _editarIntolerancias() async {
    final all = await HogarService().fetchIntolerancias();
    Set<int> selected = _intolerancias.map((i) => i.id).toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Intolerancias de ${widget.member.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: all.map((item) {
                    final isSelected = selected.contains(item.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(item.nombre),
                      activeColor: _accent,
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
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await HogarService().updateIntolerancias(
                      hogarId: widget.hogarId,
                      memberId: widget.member.id,
                      intoleranciasIds: selected.toList(),
                    );
                    if (!mounted) return;
                    final updated = await HogarService().fetchIntolerancias();
                    final selectedList = updated
                        .where((i) => selected.contains(i.id))
                        .toList();
                    setState(() => _intolerancias = selectedList);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      if (_canEditFullProfile) {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El nombre no puede estar vacío')),
          );
          setState(() => _saving = false);
          return;
        }
        final birthDateStr = _birthDate != null ? _birthDateToApi(_birthDate!) : null;
        await HogarService().updatePerfilMiembro(
          hogarId: widget.hogarId,
          userId: widget.member.id,
          name: name,
          birthDate: birthDateStr,
        );
      }

      await HogarService().updateNotasMiembro(
        hogarId: widget.hogarId,
        userId: widget.member.id,
        notas: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardado')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.member.name.isNotEmpty
        ? widget.member.name.trim().toUpperCase()[0]
        : '?';
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;

    return MainLayout(
      title: widget.member.name,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _canEditFullProfile ? _pickAndUploadAvatar : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: widget.member.esPropietario
                          ? _ownerGold.withOpacity(0.2)
                          : _accent.withOpacity(0.15),
                      backgroundImage: hasAvatar
                          ? CachedNetworkImageProvider(_avatarUrl!)
                          : null,
                      onBackgroundImageError: hasAvatar ? (_, __) {} : null,
                      child: hasAvatar
                          ? null
                          : Text(
                              initial,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: widget.member.esPropietario
                                    ? _ownerGold
                                    : _accent,
                              ),
                            ),
                    ),
                    if (_canEditFullProfile)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: _accent,
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nombre',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            _canEditFullProfile
                ? TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Nombre del miembro',
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      widget.member.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
            const SizedBox(height: 16),
            Text(
              'Fecha de nacimiento',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            _canEditFullProfile
                ? TextField(
                    controller: _birthDateController,
                    readOnly: true,
                    onTap: () async {
                      final initial = _birthDate ?? DateTime(DateTime.now().year - 30);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        helpText: 'Seleccionar fecha de nacimiento',
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _birthDate = picked;
                          _birthDateController.text = _formatBirthDate(picked);
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'dd/mm/aaaa (opcional)',
                      suffixIcon: Icon(Icons.calendar_today, size: 20),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      _birthDate != null
                          ? _formatBirthDate(_birthDate!)
                          : (widget.member.edad != null
                              ? '${widget.member.edad} años'
                              : '—'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
            if (!widget.member.esFicticio) ...[
              const SizedBox(height: 8),
              Text(
                widget.member.email ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Notas (para este hogar)',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            _canEditNotesAndIntolerances
                ? TextField(
                    controller: _notasController,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Notas opcionales',
                      alignLabelWithHint: true,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      widget.member.notas ?? '—',
                      style: const TextStyle(fontSize: 14, height: 1.35),
                    ),
                  ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Restricciones alimentarias',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (_canEditNotesAndIntolerances)
                  TextButton(
                    onPressed: _saving ? null : _editarIntolerancias,
                    child: const Text('Editar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _intolerancias.isEmpty
                  ? [
                      Text(
                        'Ninguna',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ]
                  : _intolerancias
                      .map(
                        (i) => Chip(
                          label: Text(i.nombre),
                          backgroundColor: AppColors.brandGreen.withOpacity(0.15),
                          side: BorderSide(color: AppColors.brandGreen.withOpacity(0.4)),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 32),
            if (_canEditFullProfile || _canEditNotesAndIntolerances)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
