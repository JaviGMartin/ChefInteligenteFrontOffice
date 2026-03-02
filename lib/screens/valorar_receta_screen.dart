import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme/app_colors.dart';
import '../services/recipe_service.dart';
import '../widgets/main_layout.dart';

/// Pantalla para valorar una receta (puntuación 1-5 y comentario opcional) tras cocinarla.
/// Solo se muestra cuando la receta no es del usuario. La valoración queda pendiente de revisión por el admin.
class ValorarRecetaScreen extends StatefulWidget {
  const ValorarRecetaScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<ValorarRecetaScreen> createState() => _ValorarRecetaScreenState();
}

class _ValorarRecetaScreenState extends State<ValorarRecetaScreen> {
  int _puntuacion = 0;
  final _comentarioController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_puntuacion < 1 || _puntuacion > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige una puntuación del 1 al 5.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _enviando = true);
    try {
      await RecipeService().valorar(
        widget.recipe.id,
        _puntuacion,
        comentario: _comentarioController.text.trim().isEmpty ? null : _comentarioController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valoración enviada. Será visible cuando un administrador la apruebe.'),
          backgroundColor: AppColors.brandGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _insertarEmoji(String emoji) {
    final c = _comentarioController;
    final start = c.selection.start.clamp(0, c.text.length);
    c.text = c.text.substring(0, start) + emoji + c.text.substring(start);
    c.selection = TextSelection.collapsed(offset: start + emoji.length);
    setState(() {});
  }

  static const List<String> _emojisComentario = [
    '😀', '😊', '👍', '❤️', '😋', '🍳', '👌', '😍', '🙏', '😅',
  ];

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Valorar receta',
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.recipe.titulo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿Qué te ha parecido? Tu valoración y comentario serán revisados antes de hacerse públicos.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Puntuación (1-5)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final valor = i + 1;
                      final seleccionado = _puntuacion >= valor;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: IconButton(
                          onPressed: _enviando ? null : () => setState(() => _puntuacion = valor),
                          icon: Icon(
                            seleccionado ? Icons.star : Icons.star_border,
                            size: 40,
                            color: seleccionado ? AppColors.brandGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Comentario (opcional)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _emojisComentario.map((emoji) {
                      return InkWell(
                        onTap: _enviando ? null : () => _insertarEmoji(emoji),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _comentarioController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu opinión sobre la receta...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    enabled: !_enviando,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _enviando ? null : _enviar,
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_enviando ? 'Enviando…' : 'Enviar valoración'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.brandBlue,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _enviando ? null : () => Navigator.of(context).pop(true),
                  child: const Text('Omitir y salir'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
