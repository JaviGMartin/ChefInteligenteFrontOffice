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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _service.fetchMisIncidencias();
    });
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
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.messageCircle, size: 64, color: AppColors.onStainlessMuted),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes incidencias ni propuestas.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.onStainlessMuted,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pulsa + para reportar un problema o enviar una propuesta.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onStainlessMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IncidenciaDetailScreen(incidencia: inc),
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
class IncidenciaDetailScreen extends StatelessWidget {
  final Incidencia incidencia;

  const IncidenciaDetailScreen({super.key, required this.incidencia});

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
        title: Text(
          incidencia.asunto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.brandBlue,
        foregroundColor: AppColors.brandWhite,
      ),
      body: StainlessBackground(
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
                isUser: false,
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
