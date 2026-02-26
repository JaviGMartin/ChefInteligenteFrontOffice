import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/hogar_service.dart';
import '../../models/intolerancia.dart';
import '../../theme/app_colors.dart';
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
  // Perfil nutricional (todos opcionales)
  late TextEditingController _pesoKgController;
  late TextEditingController _alturaCmController;
  late TextEditingController _pesoHabitualController;
  late TextEditingController _cinturaCmController;
  late TextEditingController _caderaCmController;
  late TextEditingController _condicionesMedicasController;
  late TextEditingController _medicacionController;
  String? _sexo;
  String? _nivelActividad;
  String? _objetivoDietetico;
  String? _embarazoLactancia;

  @override
  void initState() {
    super.initState();
    final user = AuthService.userNotifier.value;
    _nameController = TextEditingController(text: user?.name ?? '');
    _notasController = TextEditingController(text: user?.notas ?? '');
    _birthDate = user?.birthDate;
    _selectedIntoleranciaIds = Set.from(user?.intoleranciaIds ?? []);
    _pesoKgController = TextEditingController(text: user?.pesoKg != null ? user!.pesoKg.toString() : '');
    _alturaCmController = TextEditingController(text: user?.alturaCm != null ? user!.alturaCm.toString() : '');
    _pesoHabitualController = TextEditingController(text: user?.pesoHabitualKg != null ? user!.pesoHabitualKg.toString() : '');
    _cinturaCmController = TextEditingController(text: user?.circunferenciaCinturaCm != null ? user!.circunferenciaCinturaCm.toString() : '');
    _caderaCmController = TextEditingController(text: user?.circunferenciaCaderaCm != null ? user!.circunferenciaCaderaCm.toString() : '');
    _condicionesMedicasController = TextEditingController(text: user?.condicionesMedicas ?? '');
    _medicacionController = TextEditingController(text: user?.medicacionActual ?? '');
    _sexo = user?.sexo;
    _nivelActividad = user?.nivelActividad;
    _objetivoDietetico = user?.objetivoDietetico;
    _embarazoLactancia = user?.embarazoLactancia;
    _loadIntolerancias();
  }

  double? get _pesoKg => double.tryParse(_pesoKgController.text.trim());
  double? get _alturaCm => double.tryParse(_alturaCmController.text.trim());
  double? get _pesoHabitualKg => double.tryParse(_pesoHabitualController.text.trim());
  double? get _cinturaCm => double.tryParse(_cinturaCmController.text.trim());
  double? get _caderaCm => double.tryParse(_caderaCmController.text.trim());
  double? get _localImc {
    final p = _pesoKg;
    final a = _alturaCm;
    if (p == null || a == null || a <= 0) return null;
    return p / ((a / 100) * (a / 100));
  }
  double? get _localIcc {
    final c = _cinturaCm;
    final d = _caderaCm;
    if (c == null || d == null || d <= 0) return null;
    return c / d;
  }
  double? get _localTmb {
    final p = _pesoKg;
    final a = _alturaCm;
    if (p == null || a == null || _sexo == null || _edad == null) return null;
    var tmb = 10 * p + 6.25 * a - 5 * _edad!;
    if (_sexo == 'M') tmb += 5; else tmb -= 161;
    return tmb.roundToDouble();
  }
  double? get _localGet {
    final tmb = _localTmb;
    if (tmb == null || _nivelActividad == null) return null;
    const factors = {'sedentario': 1.2, 'ligero': 1.375, 'moderado': 1.55, 'activo': 1.725, 'muy_activo': 1.9};
    final f = factors[_nivelActividad!];
    if (f == null) return null;
    return (tmb * f).roundToDouble();
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
        pesoKg: _pesoKg,
        alturaCm: _alturaCm,
        pesoHabitualKg: _pesoHabitualKg,
        circunferenciaCinturaCm: _cinturaCm,
        circunferenciaCaderaCm: _caderaCm,
        sexo: _sexo,
        nivelActividad: _nivelActividad,
        objetivoDietetico: _objetivoDietetico,
        condicionesMedicas: _condicionesMedicasController.text.trim().isEmpty ? null : _condicionesMedicasController.text.trim(),
        medicacionActual: _medicacionController.text.trim().isEmpty ? null : _medicacionController.text.trim(),
        embarazoLactancia: _sexo == 'M' ? 'no' : _embarazoLactancia,
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

  Widget _buildNutricionSection(BuildContext context) {
    return ExpansionTile(
      title: const Text('Perfil nutricional'),
      subtitle: const Text(
        'Opcional. Para dieta personalizada (ej. clientes Gold).',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
      ),
      initiallyExpanded: _pesoKg != null || _alturaCm != null || _sexo != null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _pesoKgController,
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  helperText: 'Tu peso actual.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _alturaCmController,
                decoration: const InputDecoration(
                  labelText: 'Altura (cm)',
                  helperText: 'Tu altura en centímetros.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pesoHabitualController,
                decoration: const InputDecoration(
                  labelText: 'Peso habitual (kg)',
                  helperText: 'El peso que solías tener antes de cambios recientes; sirve de referencia al nutricionista.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cinturaCmController,
                      decoration: const InputDecoration(
                        labelText: 'Cintura (cm)',
                        helperText: 'Perímetro de cintura.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _caderaCmController,
                      decoration: const InputDecoration(
                        labelText: 'Cadera (cm)',
                        helperText: 'Perímetro de cadera.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _sexo,
                decoration: const InputDecoration(
                  labelText: 'Sexo',
                  helperText: 'Para fórmulas de gasto energético.',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Hombre')),
                  DropdownMenuItem(value: 'F', child: Text('Mujer')),
                  DropdownMenuItem(value: 'otro', child: Text('Otro')),
                  DropdownMenuItem(value: 'no_indica', child: Text('No indicar')),
                ],
                onChanged: (v) => setState(() => _sexo = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _nivelActividad,
                decoration: const InputDecoration(
                  labelText: 'Nivel de actividad',
                  helperText: 'Qué tan activo eres en el día a día; afecta el cálculo de calorías.',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'sedentario', child: Text('Sedentario')),
                  DropdownMenuItem(value: 'ligero', child: Text('Ligero')),
                  DropdownMenuItem(value: 'moderado', child: Text('Moderado')),
                  DropdownMenuItem(value: 'activo', child: Text('Activo')),
                  DropdownMenuItem(value: 'muy_activo', child: Text('Muy activo')),
                ],
                onChanged: (v) => setState(() => _nivelActividad = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _objetivoDietetico,
                decoration: const InputDecoration(
                  labelText: 'Objetivo dietético',
                  helperText: 'Meta principal de la dieta.',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'mantener_peso', child: Text('Mantener peso')),
                  DropdownMenuItem(value: 'perder_peso', child: Text('Perder peso')),
                  DropdownMenuItem(value: 'ganar_peso', child: Text('Ganar peso')),
                  DropdownMenuItem(value: 'rendimiento_deportivo', child: Text('Rendimiento deportivo')),
                  DropdownMenuItem(value: 'otro', child: Text('Otro')),
                ],
                onChanged: (v) => setState(() => _objetivoDietetico = v),
              ),
              if (_sexo != 'M') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _embarazoLactancia,
                  decoration: const InputDecoration(
                    labelText: 'Embarazo / lactancia',
                    helperText: 'Afecta las necesidades nutricionales.',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'no', child: Text('No')),
                    DropdownMenuItem(value: 'embarazada', child: Text('Embarazada')),
                    DropdownMenuItem(value: 'lactancia', child: Text('Lactancia')),
                  ],
                  onChanged: (v) => setState(() => _embarazoLactancia = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _condicionesMedicasController,
                decoration: const InputDecoration(
                  labelText: 'Condiciones médicas',
                  helperText: 'Enfermedades o trastornos que puedan afectar la dieta (ej. diabetes, HTA).',
                  hintText: 'Ej: diabetes, HTA, gastritis...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _medicacionController,
                decoration: const InputDecoration(
                  labelText: 'Medicación actual',
                  helperText: 'Medicamentos que tomes de forma habitual y puedan influir en la dieta.',
                  hintText: 'Medicamentos que puedan afectar la dieta',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
              if (_localImc != null || _localIcc != null || _localTmb != null || _localGet != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Valores calculados',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IMC: Índice de masa corporal (peso/altura²). ICC: Índice cintura/cadera. '
                  'TMB: calorías en reposo al día. GET: calorías totales al día según tu actividad.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (_localImc != null)
                      Chip(
                        label: Text('IMC: ${_localImc!.toStringAsFixed(1)} kg/m²'),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    if (_localIcc != null)
                      Chip(
                        label: Text('ICC: ${_localIcc!.toStringAsFixed(2)}'),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    if (_localTmb != null)
                      Chip(
                        label: Text('TMB: ${_localTmb!.toInt()} kcal/día'),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    if (_localGet != null)
                      Chip(
                        label: Text('GET: ${_localGet!.toInt()} kcal/día'),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
    _pesoKgController.dispose();
    _alturaCmController.dispose();
    _pesoHabitualController.dispose();
    _cinturaCmController.dispose();
    _caderaCmController.dispose();
    _condicionesMedicasController.dispose();
    _medicacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                                      backgroundColor: AppColors.stainlessLight,
                                      backgroundImage: hasAvatar
                                          ? CachedNetworkImageProvider(
                                              avatarUrl)
                                          : null,
                                      child: hasAvatar
                                          ? null
                                          : Text(
                                              initial,
                                              style: TextStyle(
                                                color: AppColors.brandGreen,
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
                                    color: AppColors.brandGreen,
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
                            selectedColor: AppColors.brandGreen.withOpacity(0.3),
                            checkmarkColor: AppColors.brandGreen,
                            side: BorderSide(
                              color: selected
                                  ? AppColors.brandGreen
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
                      _buildNutricionSection(context),
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
