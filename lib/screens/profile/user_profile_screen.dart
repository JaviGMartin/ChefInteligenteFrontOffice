import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/hogar_service.dart';
import '../../models/intolerancia.dart';
import '../../widgets/main_layout.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notasController;
  DateTime? _birthDate;
  List<Intolerancia> _allIntolerancias = [];
  Set<int> _selectedIntoleranciaIds = {};
  bool _loading = true;
  bool _saving = false;
  bool _changingPassword = false;
  String? _loadError;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = AuthService.userNotifier.value;
    _nameController = TextEditingController(text: user?.name ?? '');
    _notasController = TextEditingController(text: user?.notas ?? '');
    _birthDate = user?.birthDate;
    _selectedIntoleranciaIds = Set.from(user?.intoleranciaIds ?? []);
    _loadIntolerancias();
  }

  Future<void> _loadIntolerancias() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await HogarService().fetchIntolerancias();
      if (mounted) {
        setState(() {
          _allIntolerancias = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  int? get _edad {
    if (_birthDate == null) return null;
    final now = DateTime.now();
    var age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month ||
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  void _showAvatarSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUploadAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUploadAvatar(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
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

      await AuthService().uploadAvatar(bytes, filename);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto actualizada')),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _guardar() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService().updateProfile(
        name: name,
        birthDate: _birthDate,
        notas: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
        intoleranciaIds: _selectedIntoleranciaIds.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
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

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(),
                  helperText: 'Mínimo 8 caracteres',
                ),
                obscureText: true,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                autocorrect: false,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final current = currentController.text;
              final newPwd = newController.text;
              final confirm = confirmController.text;
              if (current.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Indica la contraseña actual')),
                );
                return;
              }
              if (newPwd.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('La nueva contraseña debe tener al menos 8 caracteres')),
                );
                return;
              }
              if (newPwd != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('La confirmación no coincide con la nueva contraseña')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              setState(() => _changingPassword = true);
              try {
                await AuthService().changePassword(
                  currentPassword: current,
                  newPassword: newPwd,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contraseña actualizada')),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _changingPassword = false);
              }
            },
            child: const Text('Cambiar contraseña'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const verdeBetis = Color(0xFF00914E);

    return MainLayout(
      title: 'Mi Perfil',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _loadIntolerancias,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ValueListenableBuilder<AuthUser?>(
                        valueListenable: AuthService.userNotifier,
                        builder: (context, user, _) {
                          final avatarUrl = user?.avatarUrl;
                          final hasAvatar =
                              avatarUrl != null && avatarUrl.isNotEmpty;
                          final name = user?.name ?? '';
                          final initial = name.isNotEmpty
                              ? name.trim().toUpperCase()[0]
                              : '?';
                          return Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Material(
                                  elevation: 2,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: _showAvatarSourceSheet,
                                    customBorder: const CircleBorder(),
                                    child: CircleAvatar(
                                      radius: 48,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: hasAvatar
                                          ? CachedNetworkImageProvider(
                                              avatarUrl)
                                          : null,
                                      child: hasAvatar
                                          ? null
                                          : Text(
                                              initial,
                                              style: TextStyle(
                                                color: verdeBetis,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 32,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Material(
                                    color: verdeBetis,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: _showAvatarSourceSheet,
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Fecha de nacimiento'),
                        subtitle: Text(
                          _birthDate != null
                              ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                                  '${_edad != null ? ' ($_edad años)' : ''}'
                              : 'No indicada',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickBirthDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: Theme.of(context).dividerColor),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Intolerancias / alérgenos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allIntolerancias.map((item) {
                          final selected =
                              _selectedIntoleranciaIds.contains(item.id);
                          return FilterChip(
                            label: Text(item.nombre),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedIntoleranciaIds.add(item.id);
                                } else {
                                  _selectedIntoleranciaIds.remove(item.id);
                                }
                              });
                            },
                            selectedColor: verdeBetis.withOpacity(0.3),
                            checkmarkColor: verdeBetis,
                            side: BorderSide(
                              color: selected
                                  ? verdeBetis
                                  : Theme.of(context).dividerColor,
                              width: selected ? 2 : 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _notasController,
                        decoration: const InputDecoration(
                          labelText: 'Notas',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                          hintText: 'Ej: preferencias, alergias adicionales...',
                        ),
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _guardar,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Guardar'),
                      ),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text('Cambiar contraseña'),
                        subtitle: const Text(
                          'Deja en blanco si no quieres cambiarla.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        leading: Icon(
                          Icons.lock_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                FilledButton.icon(
                                  onPressed: _changingPassword
                                      ? null
                                      : _showChangePasswordDialog,
                                  icon: _changingPassword
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.lock_reset, size: 20),
                                  label: Text(_changingPassword
                                      ? 'Guardando...'
                                      : 'Abrir formulario de cambio'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
