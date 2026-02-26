import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../services/incidencia_service.dart';

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
  String? _contexto;
  bool _sending = false;

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
      body: StainlessBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
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
                    labelText: 'Contexto (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('General')),
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'receta', child: Text('Receta')),
                    DropdownMenuItem(value: 'ingrediente', child: Text('Ingrediente')),
                  ],
                  onChanged: (v) => setState(() => _contexto = v),
                ),
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
  }
}
