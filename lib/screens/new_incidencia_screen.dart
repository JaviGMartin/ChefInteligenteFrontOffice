import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/recipe.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../services/incidencia_service.dart';
import '../services/recipe_service.dart';

/// Formulario para enviar una incidencia (problema) o propuesta (mejora).
class NewIncidenciaScreen extends StatefulWidget {
  const NewIncidenciaScreen({super.key});

  @override
  State<NewIncidenciaScreen> createState() => _NewIncidenciaScreenState();
}

class _NewIncidenciaScreenState extends State<NewIncidenciaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _asuntoController = TextEditingController();
  final _cuerpoController = TextEditingController();

  String _tipo = 'incidencia';
  String _contexto = 'general';
  int? _recetaId;
  int? _ingredienteId;
  bool _sending = false;
  List<Recipe> _recetas = [];
  List<Ingredient> _ingredientes = [];

  @override
  void initState() {
    super.initState();
    _loadRecetas();
    _loadIngredientes();
  }

  Future<void> _loadRecetas() async {
    try {
      final list = await RecipeService().fetchRecipes();
      if (mounted) setState(() => _recetas = list);
    } catch (_) {}
  }

  Future<void> _loadIngredientes() async {
    try {
      final list = await RecipeService().fetchIngredientes();
      if (mounted) setState(() => _ingredientes = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _asuntoController.dispose();
    _cuerpoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _sending) return;

    setState(() => _sending = true);
    try {
      await IncidenciaService().crearIncidencia(
        tipo: _tipo,
        contexto: _contexto,
        recetaId: _contexto == 'receta' ? _recetaId : null,
        ingredienteId: _contexto == 'ingrediente' ? _ingredienteId : null,
        asunto: _asuntoController.text.trim(),
        cuerpo: _cuerpoController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviado correctamente. Te responderemos desde el equipo de soporte.'),
          backgroundColor: AppColors.brandGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: AppColors.brandWhite),
        titleTextStyle: const TextStyle(
          color: AppColors.brandWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        title: const Text('Enviar a soporte'),
        backgroundColor: AppColors.brandBlue,
        foregroundColor: AppColors.brandWhite,
      ),
      drawer: const AppDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return StainlessBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                Text(
                  '¿Qué deseas enviar?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.onStainlessMuted,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'incidencia',
                      label: Text('Reportar problema'),
                      icon: Icon(LucideIcons.alertCircle),
                    ),
                    ButtonSegment(
                      value: 'propuesta',
                      label: Text('Propuesta'),
                      icon: Icon(LucideIcons.lightbulb),
                    ),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (Set<String> s) {
                    setState(() => _tipo = s.first);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _contexto,
                  decoration: const InputDecoration(
                    labelText: 'Contexto',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'receta', child: Text('Receta')),
                    DropdownMenuItem(value: 'ingrediente', child: Text('Ingrediente')),
                  ],
                  onChanged: (v) => setState(() {
                    _contexto = v ?? 'general';
                    if (_contexto != 'receta') _recetaId = null;
                    if (_contexto != 'ingrediente') _ingredienteId = null;
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Si es sobre una receta o ingrediente concreto, selecciona Receta o Ingrediente para vincularlo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                if (_contexto == 'receta') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _recetaId,
                    decoration: const InputDecoration(
                      labelText: 'Receta relacionada (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Ninguna —')),
                      ..._recetas.map((r) => DropdownMenuItem(value: r.id, child: Text(r.titulo))),
                    ],
                    onChanged: (v) => setState(() => _recetaId = v),
                  ),
                ],
                if (_contexto == 'ingrediente') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _ingredienteId,
                    decoration: const InputDecoration(
                      labelText: 'Ingrediente relacionado (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Ninguno —')),
                      ..._ingredientes.map((i) => DropdownMenuItem(value: i.id, child: Text(i.nombre))),
                    ],
                    onChanged: (v) => setState(() => _ingredienteId = v),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _asuntoController,
                  decoration: const InputDecoration(
                    labelText: 'Asunto',
                    hintText: 'Resumen breve',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 255,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Escribe un asunto';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cuerpoController,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    hintText: 'Describe el problema o tu propuesta con detalle...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Escribe el mensaje';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.send),
                  label: Text(_sending ? 'Enviando…' : 'Enviar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: AppColors.brandWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
