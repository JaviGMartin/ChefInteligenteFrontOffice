import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/incidencia.dart';
import '../theme/app_colors.dart';
import '../widgets/main_layout.dart';
import 'new_incidencia_screen.dart';
import '../services/incidencia_service.dart';

/// Lista de incidencias y propuestas del usuario; acceso al detalle del hilo y a crear nueva.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final IncidenciaService _service = IncidenciaService();
  Future<List<Incidencia>>? _future;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _service.fetchMisIncidencias(archived: _showArchived);
    });
  }

  void _switchTab(bool archived) {
    if (_showArchived == archived) return;
    setState(() {
      _showArchived = archived;
      _future = _service.fetchMisIncidencias(archived: _showArchived);
    });
  }

  Future<void> _archivar(Incidencia inc) async {
    try {
      await _service.archivarIncidencia(inc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incidencia archivada.'), backgroundColor: AppColors.brandGreen),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _eliminar(Incidencia inc, {bool fromArchived = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fromArchived ? 'Eliminar definitivamente' : 'Eliminar incidencia'),
        content: Text(
          fromArchived
              ? '¿Eliminar esta incidencia del archivo? No podrás recuperarla.'
              : '¿Eliminar esta incidencia? No podrás recuperarla.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _service.eliminarIncidencia(inc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incidencia eliminada.'), backgroundColor: AppColors.brandGreen),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openNewIncidencia() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const NewIncidenciaScreen(),
      ),
    );
    if (created == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Ayuda y soporte',
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewIncidencia,
        backgroundColor: AppColors.brandGreen,
        child: const Icon(LucideIcons.plus, color: AppColors.brandWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Activas')),
                ButtonSegment(value: true, label: Text('Archivadas')),
              ],
              selected: {_showArchived},
              onSelectionChanged: (s) => _switchTab(s.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _load();
                await _future;
              },
              child: FutureBuilder<List<Incidencia>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.alertCircle, size: 48, color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: 16),
                            Text(
                              snapshot.error.toString().replaceFirst('Exception: ', ''),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(LucideIcons.refreshCw),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.messageCircle, size: 64, color: AppColors.onStainlessMuted),
                                    const SizedBox(height: 16),
                                    Text(
                                      _showArchived
                                          ? 'No tienes incidencias archivadas.'
                                          : 'No tienes incidencias ni propuestas.',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: AppColors.onStainlessMuted,
                                          ),
                                    ),
                                    if (!_showArchived) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Pulsa + para reportar un problema o enviar una propuesta.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.onStainlessMuted,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final inc = list[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            inc.asunto,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Chip(
                                  label: Text(inc.tipoLabel, style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  inc.estadoLabel,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.onStainlessMuted,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(inc.updatedAt),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.onStainlessMuted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(LucideIcons.chevronRight),
                            onSelected: (value) async {
                              if (value == 'archivar') await _archivar(inc);
                              if (value == 'eliminar') await _eliminar(inc, fromArchived: _showArchived);
                            },
                            itemBuilder: (context) => [
                              if (!_showArchived) const PopupMenuItem(value: 'archivar', child: Text('Archivar')),
                              PopupMenuItem(
                                value: 'eliminar',
                                child: Text(_showArchived ? 'Eliminar definitivamente' : 'Eliminar'),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => IncidenciaDetailScreen(
                                  incidencia: inc,
                                  onArchivar: _showArchived ? null : () => _archivar(inc),
                                  onEliminar: () => _eliminar(inc, fromArchived: _showArchived),
                                ),
                              ),
                            ).then((_) => _load());
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

/// Detalle del hilo: asunto, estado y mensajes (cuerpo inicial + respuestas).
class IncidenciaDetailScreen extends StatefulWidget {
  final Incidencia incidencia;
  final Future<void> Function()? onArchivar;
  final Future<void> Function()? onEliminar;

  const IncidenciaDetailScreen({
    super.key,
    required this.incidencia,
    this.onArchivar,
    this.onEliminar,
  });

  @override
  State<IncidenciaDetailScreen> createState() => _IncidenciaDetailScreenState();
}

class _IncidenciaDetailScreenState extends State<IncidenciaDetailScreen> {
  late Incidencia _incidencia;
  final _replyController = TextEditingController();
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _incidencia = widget.incidencia;
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sendingReply) return;
    setState(() => _sendingReply = true);
    try {
      final updated = await IncidenciaService().addMensaje(_incidencia.id, text);
      if (!mounted) return;
      setState(() {
        _incidencia = updated;
        _replyController.clear();
        _sendingReply = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje enviado.'), backgroundColor: AppColors.brandGreen),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sendingReply = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _marcarResuelto() async {
    if (_sendingReply) return;
    setState(() => _sendingReply = true);
    try {
      final updated = await IncidenciaService().updateEstado(_incidencia.id, 'resuelto');
      if (!mounted) return;
      setState(() {
        _incidencia = updated;
        _sendingReply = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marcada como resuelta.'), backgroundColor: AppColors.brandGreen),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sendingReply = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidencia = _incidencia;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: AppColors.brandWhite),
        titleTextStyle: const TextStyle(
          color: AppColors.brandWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        title: Text(
          incidencia.asunto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.brandBlue,
        foregroundColor: AppColors.brandWhite,
        actions: [
          if (widget.onArchivar != null || widget.onEliminar != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.brandWhite),
              onSelected: (value) async {
                if (value == 'archivar' && widget.onArchivar != null) {
                  await widget.onArchivar!();
                  if (context.mounted) Navigator.of(context).pop(true);
                }
                if (value == 'eliminar' && widget.onEliminar != null) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar incidencia'),
                      content: const Text(
                        '¿Eliminar esta incidencia? No podrás recuperarla.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await widget.onEliminar!();
                    if (context.mounted) Navigator.of(context).pop(true);
                  }
                }
              },
              itemBuilder: (context) => [
                if (widget.onArchivar != null && !incidencia.isArchived)
                  const PopupMenuItem(value: 'archivar', child: Text('Archivar')),
                if (widget.onEliminar != null)
                  const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
        ],
      ),
      body: StainlessBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Chip(label: Text(incidencia.tipoLabel)),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(incidencia.estadoLabel),
                        backgroundColor: _estadoColor(incidencia.estado).withOpacity(0.2),
                      ),
                    ],
                  ),
                  if (incidencia.recetaTitulo != null || incidencia.ingredienteNombre != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (incidencia.recetaTitulo != null)
                          Chip(
                            avatar: const Icon(Icons.restaurant, size: 18, color: AppColors.brandBlue),
                            label: Text('Receta: ${incidencia.recetaTitulo}'),
                          ),
                        if (incidencia.ingredienteNombre != null)
                          Chip(
                            avatar: const Icon(Icons.shopping_basket, size: 18, color: AppColors.brandBlue),
                            label: Text('Ingrediente: ${incidencia.ingredienteNombre}'),
                          ),
                      ],
                    ),
                  ],
                  if (incidencia.estado == 'en_curso') ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _sendingReply ? null : _marcarResuelto,
                      icon: const Icon(LucideIcons.checkCircle, size: 20),
                      label: const Text('Marcar como resuelto'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: AppColors.brandWhite,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _MessageBubble(
                    text: incidencia.cuerpo,
                    date: incidencia.createdAt,
                    isUser: true,
                  ),
                  ...incidencia.mensajes.map(
                    (m) => _MessageBubble(
                      text: m.mensaje,
                      date: m.createdAt,
                      isUser: m.userId == incidencia.userId,
                    ),
                  ),
                ],
              ),
            ),
            incidencia.estado != 'cerrado' && !incidencia.isArchived
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            decoration: const InputDecoration(
                              hintText: 'Escribe tu respuesta...',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLines: 3,
                            minLines: 1,
                            onSubmitted: (_) => _sendReply(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _sendingReply ? null : _sendReply,
                          icon: _sendingReply
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(LucideIcons.send, size: 20),
                          label: const Text('Enviar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brandGreen,
                            foregroundColor: AppColors.brandWhite,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Esta incidencia está cerrada. No se pueden añadir más mensajes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onStainlessMuted,
                          ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'nuevo':
        return Colors.orange;
      case 'en_curso':
        return Colors.blue;
      case 'resuelto':
        return AppColors.brandGreen;
      case 'cerrado':
        return AppColors.onStainlessMuted;
      default:
        return AppColors.brandBlue;
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String date;
  final bool isUser;

  const _MessageBubble({
    required this.text,
    required this.date,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? AppColors.brandBlue.withOpacity(0.15) : AppColors.stainless,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUser ? AppColors.brandBlue.withOpacity(0.3) : AppColors.stainlessDark,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onStainlessMuted,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
