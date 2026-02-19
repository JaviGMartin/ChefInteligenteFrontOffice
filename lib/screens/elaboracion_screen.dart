import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/alarma_notification_service.dart';
import '../services/recipe_service.dart';
import '../state/kitchen_state.dart';
import '../widgets/main_layout.dart';

/// Formato legible del tiempo de un paso (ej. "5 min", "1 h 30 min").
String formatTiempoPaso(PasoElaboracionRecipe paso) {
  final segundos = paso.tiempoSegundos;
  if (segundos == null || segundos <= 0) return '';
  final um = paso.tiempoUnidadMedida;
  if (um != null && (um.abreviatura != null && um.abreviatura!.isNotEmpty)) {
    final factor = um.factorConversion;
    if (factor > 0) {
      final valor = segundos / factor;
      final v = valor.round();
      return '$v ${um.abreviatura}';
    }
  }
  if (segundos >= 3600) {
    final h = segundos ~/ 3600;
    final m = (segundos % 3600) ~/ 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }
  final m = segundos ~/ 60;
  final s = segundos % 60;
  if (s == 0) return '$m min';
  return '$m min ${s}s';
}

/// Paso aplanado para la UI (elaboracion + paso).
class _PasoPlano {
  final String elaboracionTitulo;
  final PasoElaboracionRecipe paso;

  _PasoPlano(this.elaboracionTitulo, this.paso);
}

/// Pantalla Modo Chef: elaboración paso a paso.
/// Con elaboraciones: muestra pasos uno a uno con timers e ingredientes por paso.
/// Sin elaboraciones: muestra ingredientes + instrucciones texto + marcar cocinada.
class ElaboracionScreen extends StatefulWidget {
  const ElaboracionScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<ElaboracionScreen> createState() => _ElaboracionScreenState();
}

class _ElaboracionScreenState extends State<ElaboracionScreen> {
  final Set<int> _ingredientesMarcados = {};
  bool _marcandoCocinada = false;
  Recipe? _recipe;
  int _pasoActual = 0;
  int _segundosRestantes = 0;
  Timer? _timer;
  /// En modo simplificado: índice del paso virtual actual (instrucciones divididas por líneas).
  int _pasoVirtualActual = 0;

  /// Estado por elaboración (cuando hay 2+ elaboraciones).
  final Map<int, int> _pasoPorElaboracion = {};
  /// Timer por paso: clave "elaboracionId_pasoIndex" para que cada paso tenga su propio temporizador.
  final Map<String, int> _segundosRestantesPorPaso = {};
  final Set<int> _elaboracionesActivas = {};
  final Map<String, Timer> _timersPorPaso = {};
  /// Índice del grupo de elaboraciones que se está mostrando (0-based). Solo avanza al pulsar "Continuar al siguiente grupo".
  int _indiceGrupoActual = 0;

  /// Si true, se muestra la vista de resumen (ingredientes + pasos) con botón "Empezar elaboración".
  bool _mostrandoResumenInicial = true;

  Recipe get recipe => _recipe ?? widget.recipe;

  List<ElaboracionRecipe> get _elaboraciones => recipe.elaboraciones ?? [];

  /// Grupos ordenados por número (1, 2, 3...). Elaboraciones sin grupo van al grupo 1.
  List<List<ElaboracionRecipe>> get _gruposOrdenados {
    final elabs = _elaboraciones;
    if (elabs.isEmpty) return [];
    final map = <int, List<ElaboracionRecipe>>{};
    for (final e in elabs) {
      final g = e.grupoParalelo ?? 1;
      map.putIfAbsent(g, () => []).add(e);
    }
    final keys = map.keys.toList()..sort();
    return keys.map((k) => map[k]!).toList();
  }

  /// Elaboraciones del grupo que estamos mostrando (según _indiceGrupoActual).
  List<ElaboracionRecipe> get _elaboracionesGrupoActual {
    final grupos = _gruposOrdenados;
    if (_indiceGrupoActual < 0 || _indiceGrupoActual >= grupos.length) return [];
    return grupos[_indiceGrupoActual];
  }

  /// True si todas las elaboraciones del grupo actual están completadas.
  bool get _grupoActualCompletado {
    final grupo = _elaboracionesGrupoActual;
    if (grupo.isEmpty) return true;
    return grupo.every((e) => (_pasoPorElaboracion[e.id] ?? 0) >= e.pasos.length);
  }

  /// True si hay más grupos después del actual.
  bool get _haySiguienteGrupo =>
      _indiceGrupoActual < _gruposOrdenados.length - 1;

  /// Clave única por (elaboración, paso) para timers independientes por paso.
  String _keyPaso(int elaboracionId, int pasoIndex) =>
      '${elaboracionId}_$pasoIndex';

  /// True si hay varias elaboraciones y usamos pestañas y estado por elaboración.
  bool get _usaElaboracionesParalelas => _elaboraciones.length >= 2;

  /// Pasos virtuales para modo simplificado: instrucciones divididas por saltos de línea.
  List<String> get _pasosVirtuales {
    final inst = recipe.instrucciones;
    if (inst == null || inst.isEmpty) return [];
    return inst
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<_PasoPlano> get _pasosPlanos {
    final elaboraciones = recipe.elaboraciones ?? [];
    final planos = <_PasoPlano>[];
    for (final elab in elaboraciones) {
      for (final paso in elab.pasos) {
        planos.add(_PasoPlano(elab.titulo, paso));
      }
    }
    return planos;
  }

  bool get _usaModoPasos => _pasosPlanos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cargarRecetaCompleta();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final t in _timersPorPaso.values) {
      t.cancel();
    }
    _timersPorPaso.clear();
    super.dispose();
  }

  Future<void> _cargarRecetaCompleta() async {
    try {
      final full = await RecipeService().getRecipe(widget.recipe.id);
      if (mounted) {
        setState(() => _recipe = full);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recipe = widget.recipe);
      }
    }
  }

  void _iniciarTimer(int segundos) {
    _timer?.cancel();
    if (segundos <= 0) return;
    AlarmaNotificationService.instance.cancelarNotificacionTimer(
        AlarmaNotificationService.keyTimerGlobal);
    AlarmaNotificationService.instance.programarNotificacionTimer(
      key: AlarmaNotificationService.keyTimerGlobal,
      titulo: 'Temporizador: ${recipe.titulo}',
      cuerpo: 'Ha terminado el tiempo.',
      duracion: Duration(seconds: segundos),
    );
    setState(() => _segundosRestantes = segundos);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _segundosRestantes--;
        if (_segundosRestantes <= 0) {
          _timer?.cancel();
          AlarmaNotificationService.instance
              .cancelarNotificacionTimer(AlarmaNotificationService.keyTimerGlobal);
          AlarmaNotificationService.instance.reproducirAlarma30Segundos();
        }
      });
    });
  }

  String _tituloNotificacionPaso(int elaboracionId, int pasoIndex) {
    for (final e in _elaboraciones) {
      if (e.id != elaboracionId) continue;
      final pasos = e.pasos;
      if (pasoIndex < pasos.length) {
        final desc = pasos[pasoIndex].descripcion;
        final corto = desc.length > 40 ? '${desc.substring(0, 40)}…' : desc;
        return '${recipe.titulo} – ${e.titulo}: $corto';
      }
      return '${recipe.titulo} – ${e.titulo} – Paso ${pasoIndex + 1}';
    }
    return '${recipe.titulo} – Paso ${pasoIndex + 1}';
  }

  void _iniciarTimerPorPaso(int elaboracionId, int pasoIndex, int segundos) {
    final key = _keyPaso(elaboracionId, pasoIndex);
    _timersPorPaso[key]?.cancel();
    _timersPorPaso.remove(key);
    if (segundos <= 0) return;
    AlarmaNotificationService.instance.cancelarNotificacionTimer(key);
    AlarmaNotificationService.instance.programarNotificacionTimer(
      key: key,
      titulo: 'Temporizador',
      cuerpo: _tituloNotificacionPaso(elaboracionId, pasoIndex),
      duracion: Duration(seconds: segundos),
    );
    setState(() => _segundosRestantesPorPaso[key] = segundos);
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final rest = _segundosRestantesPorPaso[key]! - 1;
        if (rest <= 0) {
          _timersPorPaso[key]?.cancel();
          _timersPorPaso.remove(key);
          _segundosRestantesPorPaso.remove(key);
          AlarmaNotificationService.instance.cancelarNotificacionTimer(key);
          AlarmaNotificationService.instance.reproducirAlarma30Segundos();
        } else {
          _segundosRestantesPorPaso[key] = rest;
        }
      });
    });
    _timersPorPaso[key] = timer;
  }

  void _detenerTimerPaso(int elaboracionId, int pasoIndex) {
    final key = _keyPaso(elaboracionId, pasoIndex);
    _timersPorPaso[key]?.cancel();
    _timersPorPaso.remove(key);
    AlarmaNotificationService.instance.cancelarNotificacionTimer(key);
    setState(() => _segundosRestantesPorPaso.remove(key));
  }

  Future<void> _marcarCocinada() async {
    if (_marcandoCocinada) return;
    setState(() => _marcandoCocinada = true);
    try {
      await RecipeService().marcarCocinada(recipe.id);
      if (!mounted) return;
      context.read<KitchenState>().loadPlanificador();
      context.read<KitchenState>().loadPendientes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Receta cocinada! Stock actualizado.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _marcandoCocinada = false);
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

  Widget _buildBannerPararAlarma() {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.timer_off, color: Theme.of(context).colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '¡Temporizador terminado!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  AlarmaNotificationService.instance.pararAlarma();
                },
                child: const Text('Parar alarma'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _mostrandoResumenInicial
        ? _buildVistaResumenInicial(context)
        : (_usaElaboracionesParalelas
            ? _buildModoElaboracionesParalelas(context)
            : _usaModoPasos
                ? _buildModoPasos(context)
                : _buildModoSimplificado(context));
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: AlarmaNotificationService.instance.alarmaSonandoNotifier,
            builder: (_, sonando, __) =>
                sonando ? _buildBannerPararAlarma() : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// Vista mostrada al entrar: listado de ingredientes y pasos para un vistazo, luego "Empezar elaboración".
  Widget _buildVistaResumenInicial(BuildContext context) {
    return MainLayout(
      title: recipe.titulo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildResumenInicialIngredientes(context),
            const SizedBox(height: 24),
            _buildResumenInicialPasos(context),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => setState(() => _mostrandoResumenInicial = false),
              icon: const Icon(Icons.play_arrow, size: 24),
              label: const Text('Empezar elaboración'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ingredientes en resumen inicial (solo lectura, con metadata opcional).
  Widget _buildResumenInicialIngredientes(BuildContext context) {
    final meta = <String>[];
    if (recipe.tiempoPreparacion != null && recipe.tiempoPreparacion! > 0) {
      meta.add('${recipe.tiempoPreparacion} min');
    }
    if (recipe.porcionesBase != null && recipe.porcionesBase! > 0) {
      meta.add('${recipe.porcionesBase} raciones');
    }
    if (recipe.dificultad != null && recipe.dificultad!.isNotEmpty) {
      meta.add(recipe.dificultad!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meta.isNotEmpty) ...[
          Text(
            meta.join(' · '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Ingredientes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (recipe.ingredientes.isEmpty)
          Text(
            'Sin ingredientes listados.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          ...recipe.ingredientes.map((ing) => _buildIngredienteLineaLectura(context, ing)),
      ],
    );
  }

  /// Una línea de ingrediente solo lectura (viñeta alineada con títulos).
  Widget _buildIngredienteLineaLectura(BuildContext context, Ingredient ing) {
    final cantidadTexto = ing.cantidad != null && ing.unidadMedida != null
        ? '${ing.cantidad} ${ing.unidadMedida!.abreviatura ?? ing.unidadMedida!.nombre}'
        : '';
    final nombreCompleto = cantidadTexto.isNotEmpty
        ? '$cantidadTexto de ${ing.nombre}'
        : ing.nombre;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nombreCompleto,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Pasos en resumen inicial: lista numerada según modo (paralelo / pasos / simplificado).
  Widget _buildResumenInicialPasos(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pasos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (_usaElaboracionesParalelas) ...[
          ..._gruposOrdenados.asMap().entries.expand((entry) {
            final numGrupo = entry.key + 1;
            final grupo = entry.value;
            return [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'Grupo $numGrupo',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              ...grupo.expand((e) => [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        e.titulo,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    ...e.pasos.asMap().entries.map((pasoEntry) {
                      final idx = pasoEntry.key;
                      final p = pasoEntry.value;
                      final corto = p.descripcion.length > 60
                          ? '${p.descripcion.substring(0, 60)}…'
                          : p.descripcion;
                      final extra = [
                        if (formatTiempoPaso(p).isNotEmpty) formatTiempoPaso(p),
                        if (p.temperatura != null && p.temperatura!.isNotEmpty) p.temperatura!,
                      ].join(' · ');
                      return Padding(
                        padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${idx + 1}. ',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Expanded(
                              child: Text(
                                extra.isNotEmpty ? '$corto ($extra)' : corto,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ]),
            ];
          }),
        ] else if (_usaModoPasos) ...[
          ..._pasosPlanos.asMap().entries.map((entry) {
            final idx = entry.key;
            final plano = entry.value;
            final corto = plano.paso.descripcion.length > 60
                ? '${plano.paso.descripcion.substring(0, 60)}…'
                : plano.paso.descripcion;
            final extra = [
              if (formatTiempoPaso(plano.paso).isNotEmpty) formatTiempoPaso(plano.paso),
              if (plano.paso.temperatura != null && plano.paso.temperatura!.isNotEmpty)
                plano.paso.temperatura!,
            ].join(' · ');
            return Padding(
              padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${idx + 1}. ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (plano.elaboracionTitulo.isNotEmpty)
                          Text(
                            plano.elaboracionTitulo,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        Text(
                          extra.isNotEmpty ? '$corto ($extra)' : corto,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          if (_pasosVirtuales.isNotEmpty)
            ..._pasosVirtuales.asMap().entries.map((entry) {
              final idx = entry.key;
              final linea = entry.value;
              final corto = linea.length > 60 ? '${linea.substring(0, 60)}…' : linea;
              return Padding(
                padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${idx + 1}. ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Expanded(
                      child: Text(
                        corto,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            })
          else if (recipe.instrucciones != null && recipe.instrucciones!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                recipe.instrucciones!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Text(
              'Sin pasos detallados.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ],
    );
  }

  /// Barra compacta de progreso (título + porcentaje + barra). Siempre visible en modo paralelo entre título de grupo y pestañas.
  Widget _buildBarraProgresoCompacta(BuildContext context, int totalPasos, int completados) {
    final progreso = totalPasos > 0 ? (completados / totalPasos).clamp(0.0, 1.0) : 0.0;
    final quedan = totalPasos - completados;
    return Card(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progreso',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '${(progreso * 100).round()}% · $completados/$totalPasos pasos'
                        '${quedan > 0 ? ' · Quedan $quedan' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progreso,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  /// Ingredientes únicos de una elaboración (los que aparecen en sus pasos).
  List<Ingredient> _ingredientesDeElaboracion(ElaboracionRecipe elab) {
    final ids = <int>{};
    final list = <Ingredient>[];
    for (final paso in elab.pasos) {
      for (final ing in paso.ingredientes) {
        if (ids.add(ing.id)) list.add(ing);
      }
    }
    return list;
  }

  /// Panel con lista de pasos (check en finalizados) e ingredientes (check utilizados). Solo en ventana de resumen.
  /// [elaboracion] si no es null: resumen por elaboración (solo pasos e ingredientes de esa elaboración).
  Widget _buildPanelProgreso(BuildContext context, {ElaboracionRecipe? elaboracion}) {
    int totalPasos;
    int completados;
    Widget listaPasos;
    List<Ingredient> ingredientesParaMostrar;

    if (_usaElaboracionesParalelas && elaboracion != null) {
      final e = elaboracion;
      final pasoIdx = _pasoPorElaboracion[e.id] ?? 0;
      totalPasos = e.pasos.length;
      completados = pasoIdx.clamp(0, e.pasos.length);
      listaPasos = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              e.titulo,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ...e.pasos.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            final hecho = idx < pasoIdx;
            final corto = p.descripcion.length > 50
                ? '${p.descripcion.substring(0, 50)}…'
                : p.descripcion;
            return Padding(
              padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hecho ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: hecho
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      corto,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: hecho ? FontWeight.w500 : null,
                            color: hecho
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
      ingredientesParaMostrar = _ingredientesDeElaboracion(e);
    } else if (_usaElaboracionesParalelas) {
      final grupo = _elaboracionesGrupoActual;
      totalPasos = grupo.fold<int>(0, (s, e) => s + e.pasos.length);
      completados = grupo.fold<int>(
        0,
        (s, e) => s + ((_pasoPorElaboracion[e.id] ?? 0).clamp(0, e.pasos.length)),
      );
      listaPasos = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: grupo.expand((e) {
          final pasoIdx = _pasoPorElaboracion[e.id] ?? 0;
          return [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                e.titulo,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...e.pasos.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final hecho = idx < pasoIdx;
              final corto = p.descripcion.length > 50
                  ? '${p.descripcion.substring(0, 50)}…'
                  : p.descripcion;
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      hecho ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: hecho
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        corto,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: hecho ? FontWeight.w500 : null,
                              color: hecho
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : null,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ];
        }).toList(),
      );
      ingredientesParaMostrar = recipe.ingredientes;
    } else if (_usaModoPasos) {
      final pasos = _pasosPlanos;
      totalPasos = pasos.length;
      completados = _pasoActual;
      ingredientesParaMostrar = recipe.ingredientes;
      listaPasos = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pasos.asMap().entries.map((entry) {
          final idx = entry.key;
          final plano = entry.value;
          final hecho = idx < _pasoActual;
          final esActual = idx == _pasoActual;
          final corto = plano.paso.descripcion.length > 50
              ? '${plano.paso.descripcion.substring(0, 50)}…'
              : plano.paso.descripcion;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hecho ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: hecho
                      ? Theme.of(context).colorScheme.primary
                      : (esActual
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    corto,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: esActual ? FontWeight.w600 : null,
                          color: hecho
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                        ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      final pasosV = _pasosVirtuales;
      totalPasos = pasosV.isEmpty ? 1 : pasosV.length;
      completados = _pasoVirtualActual;
      ingredientesParaMostrar = recipe.ingredientes;
      listaPasos = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pasosV.isEmpty
            ? [const SizedBox.shrink()]
            : pasosV.asMap().entries.map((entry) {
                final idx = entry.key;
                final linea = entry.value;
                final hecho = idx < _pasoVirtualActual;
                final esActual = idx == _pasoVirtualActual;
                final corto = linea.length > 50 ? '${linea.substring(0, 50)}…' : linea;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        hecho ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: hecho
                            ? Theme.of(context).colorScheme.primary
                            : (esActual
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          corto,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: esActual ? FontWeight.w600 : null,
                                color: hecho
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : null,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pasos',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            listaPasos,
            const SizedBox(height: 12),
            Text(
              'Ingredientes',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            if (ingredientesParaMostrar.isEmpty)
              Text(
                'Sin ingredientes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...ingredientesParaMostrar.map((ing) => _buildIngredienteCheck(context, ing)),
          ],
        ),
      ),
    );
  }

  /// True si el grupo actual está completado y no hay siguiente grupo (mostrar "Marcar como cocinada").
  bool get _todasElaboracionesCompletadas =>
      _usaElaboracionesParalelas &&
      _grupoActualCompletado &&
      !_haySiguienteGrupo;

  void _iniciarElaboracion(int elaboracionId) {
    setState(() {
      _elaboracionesActivas.add(elaboracionId);
      _pasoPorElaboracion[elaboracionId] = 0;
    });
  }

  Widget _buildModoElaboracionesParalelas(BuildContext context) {
    final elaboracionesGrupo = _elaboracionesGrupoActual;
    final numGrupo = _indiceGrupoActual + 1;

    return MainLayout(
      title: recipe.titulo,
      child: elaboracionesGrupo.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No hay elaboraciones en este grupo.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : DefaultTabController(
              length: elaboracionesGrupo.length,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Grupo elaboraciones simultáneas $numGrupo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    child: _buildBarraProgresoCompacta(
                      context,
                      _elaboraciones.fold<int>(0, (s, e) => s + e.pasos.length),
                      _elaboraciones.fold<int>(
                        0,
                        (s, e) => s + ((_pasoPorElaboracion[e.id] ?? 0).clamp(0, e.pasos.length)),
                      ),
                    ),
                  ),
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBar(
                      isScrollable: true,
                      tabs: elaboracionesGrupo.map((e) => Tab(text: e.titulo)).toList(),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: elaboracionesGrupo
                          .map((e) => _buildContenidoElaboracion(context, e))
                          .toList(),
                    ),
                  ),
                  if (_grupoActualCompletado && _haySiguienteGrupo) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () => setState(() => _indiceGrupoActual++),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_forward),
                              SizedBox(width: 8),
                              Text('Continuar al siguiente grupo'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_todasElaboracionesCompletadas) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _marcandoCocinada ? null : _marcarCocinada,
                          icon: _marcandoCocinada
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle, size: 24),
                          label: Text(
                            _marcandoCocinada ? 'Guardando…' : 'He terminado - Marcar como cocinada',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildContenidoElaboracion(BuildContext context, ElaboracionRecipe elab) {
    final elaboracionId = elab.id;
    final iniciada = _elaboracionesActivas.contains(elaboracionId);
    if (!iniciada) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                elab.titulo,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _iniciarElaboracion(elaboracionId),
                icon: const Icon(Icons.play_arrow),
                label: Text('Iniciar ${elab.titulo}'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pasoIdx = _pasoPorElaboracion[elaboracionId] ?? 0;
    final pasos = elab.pasos;
    final enUltimoPaso = pasoIdx >= pasos.length;
    final pasoActual = pasoIdx < pasos.length ? pasos[pasoIdx] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (enUltimoPaso) _buildPanelProgreso(context, elaboracion: elab),
          if (pasoActual != null) ...[
            Row(
              children: [
                Chip(
                  avatar: Icon(
                    Icons.list_alt,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    'Paso ${pasoIdx + 1} de ${pasos.length}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: pasos.isEmpty ? 0 : (pasoIdx + 1) / pasos.length,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                pasoActual.descripcion,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (pasoActual.tiempoSegundos != null && pasoActual.tiempoSegundos! > 0) ...[
              const SizedBox(height: 16),
              if (formatTiempoPaso(pasoActual).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    formatTiempoPaso(pasoActual),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              _buildTimerPaso(elaboracionId, pasoIdx, pasoActual.tiempoSegundos!),
            ],
            if (pasoActual.temperatura != null && pasoActual.temperatura!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: Icon(Icons.thermostat, size: 20, color: Theme.of(context).colorScheme.primary),
                label: Text(pasoActual.temperatura!),
              ),
            ],
            if (pasoActual.ingredientes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Ingredientes para este paso',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...pasoActual.ingredientes.map((ing) => _buildIngredienteCheck(context, ing)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if (pasoIdx > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _pasoPorElaboracion[elaboracionId] = pasoIdx - 1);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Anterior'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                if (pasoIdx > 0) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        final nuevoIdx = pasoIdx + 1;
                        _pasoPorElaboracion[elaboracionId] = nuevoIdx;
                        if (nuevoIdx >= pasos.length) {
                          for (final paso in elab.pasos) {
                            for (final ing in paso.ingredientes) {
                              _ingredientesMarcados.add(ing.id);
                            }
                          }
                        }
                      });
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(pasoIdx < pasos.length - 1 ? 'Siguiente paso' : 'Ver resumen'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (enUltimoPaso && pasos.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '${elab.titulo} completado.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerPaso(int elaboracionId, int pasoIndex, int segundos) {
    final key = _keyPaso(elaboracionId, pasoIndex);
    final total = segundos;
    final restantes = _segundosRestantesPorPaso[key] ?? total;
    final minutos = restantes ~/ 60;
    final segs = restantes % 60;
    final activo = _timersPorPaso.containsKey(key);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: activo
                  ? () => _detenerTimerPaso(elaboracionId, pasoIndex)
                  : () => _iniciarTimerPorPaso(elaboracionId, pasoIndex, total),
              child: Text(activo ? 'Detener' : 'Iniciar temporizador'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModoPasos(BuildContext context) {
    final pasos = _pasosPlanos;
    final enUltimoPaso = _pasoActual >= pasos.length;
    final pasoActual = _pasoActual < pasos.length ? pasos[_pasoActual] : null;

    return MainLayout(
      title: recipe.titulo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (enUltimoPaso) _buildPanelProgreso(context),
            if (pasoActual != null) ...[
              Text(
                pasoActual.elaboracionTitulo,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.list_alt,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      'Paso ${_pasoActual + 1} de ${pasos.length}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: pasos.isEmpty ? 0 : (_pasoActual + 1) / pasos.length,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pasoActual.paso.descripcion,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (pasoActual.paso.tiempoSegundos != null && pasoActual.paso.tiempoSegundos! > 0) ...[
                const SizedBox(height: 16),
                if (formatTiempoPaso(pasoActual.paso).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      formatTiempoPaso(pasoActual.paso),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                _buildTimer(pasoActual.paso.tiempoSegundos!),
              ],
              if (pasoActual.paso.temperatura != null && pasoActual.paso.temperatura!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: Icon(Icons.thermostat, size: 20, color: Theme.of(context).colorScheme.primary),
                  label: Text(pasoActual.paso.temperatura!),
                ),
              ],
              if (pasoActual.paso.ingredientes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Ingredientes para este paso',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                ...pasoActual.paso.ingredientes.map((ing) => _buildIngredienteCheck(context, ing)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_pasoActual > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _pasoActual--),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Anterior'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (_pasoActual > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _pasoActual++),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_pasoActual < pasos.length - 1 ? 'Siguiente paso' : 'Ver resumen'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (enUltimoPaso) ...[
              const SizedBox(height: 24),
              Text(
                '¡Casi listo! Revisa que todo esté como quieres.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _marcandoCocinada ? null : _marcarCocinada,
                icon: _marcandoCocinada
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(_marcandoCocinada ? 'Guardando…' : 'He terminado - Marcar como cocinada'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimer(int segundos) {
    final total = segundos;
    final restantes = _segundosRestantes > 0 ? _segundosRestantes : total;
    final minutos = restantes ~/ 60;
    final segs = restantes % 60;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _timer?.isActive == true
                  ? () {
                      _timer?.cancel();
                      AlarmaNotificationService.instance.cancelarNotificacionTimer(
                          AlarmaNotificationService.keyTimerGlobal);
                      setState(() => _segundosRestantes = 0);
                    }
                  : () => _iniciarTimer(total),
              child: Text(_timer?.isActive == true ? 'Detener' : 'Iniciar temporizador'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredienteCheck(BuildContext context, Ingredient ing) {
    final id = ing.id;
    final marcado = _ingredientesMarcados.contains(id);
    final cantidadTexto = ing.cantidad != null && ing.unidadMedida != null
        ? '${ing.cantidad} ${ing.unidadMedida!.abreviatura ?? ing.unidadMedida!.nombre}'
        : '';
    final nombreCompleto = cantidadTexto.isNotEmpty
        ? '$cantidadTexto de ${ing.nombre}'
        : ing.nombre;

    return InkWell(
      onTap: () {
        setState(() {
          if (marcado) {
            _ingredientesMarcados.remove(id);
          } else {
            _ingredientesMarcados.add(id);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Icon(
              marcado ? Icons.check_circle : Icons.radio_button_unchecked,
              color: marcado
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nombreCompleto,
                style: TextStyle(
                  decoration: marcado ? TextDecoration.lineThrough : null,
                  color: marcado ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionIngredientes(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ingredientes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (recipe.ingredientes.isEmpty)
          const Text('Sin ingredientes listados.')
        else
          ...recipe.ingredientes.map((ing) => _buildIngredienteCheck(context, ing)),
      ],
    );
  }

  Widget _buildModoSimplificado(BuildContext context) {
    final pasosVirtuales = _pasosVirtuales;
    final tienePasosVirtuales = pasosVirtuales.isNotEmpty;
    final pasoVirtualActual = tienePasosVirtuales && _pasoVirtualActual < pasosVirtuales.length
        ? pasosVirtuales[_pasoVirtualActual]
        : null;
    final tiempoTotalMin = recipe.tiempoPreparacion;
    final segundosTotales = tiempoTotalMin != null && tiempoTotalMin > 0 ? tiempoTotalMin * 60 : 0;
    final enResumenFinal = !tienePasosVirtuales || _pasoVirtualActual >= pasosVirtuales.length;

    return MainLayout(
      title: recipe.titulo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (enResumenFinal) _buildPanelProgreso(context),
            if (tiempoTotalMin != null && tiempoTotalMin > 0) ...[
              Text(
                'Tiempo total: $tiempoTotalMin min',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (segundosTotales > 0) ...[
                const SizedBox(height: 12),
                _buildTimer(segundosTotales),
              ],
              const SizedBox(height: 24),
            ],
            if (tienePasosVirtuales) ...[
              Text(
                'Elaboración',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.list_alt,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      'Paso ${_pasoVirtualActual + 1} de ${pasosVirtuales.length}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: pasosVirtuales.isEmpty ? 0 : (_pasoVirtualActual + 1) / pasosVirtuales.length,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              if (pasoVirtualActual != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pasoVirtualActual,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_pasoVirtualActual > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _pasoVirtualActual--),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Anterior'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    if (_pasoVirtualActual > 0) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_pasoVirtualActual < pasosVirtuales.length - 1) {
                              _pasoVirtualActual++;
                            }
                          });
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          _pasoVirtualActual < pasosVirtuales.length - 1 ? 'Siguiente paso' : 'Ver resumen',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else if (recipe.instrucciones != null && recipe.instrucciones!.isNotEmpty) ...[
              Text(
                'Elaboración',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  recipe.instrucciones!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _marcandoCocinada ? null : _marcarCocinada,
              icon: _marcandoCocinada
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle, size: 24),
              label: Text(_marcandoCocinada ? 'Guardando…' : 'He terminado - Marcar como cocinada'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
