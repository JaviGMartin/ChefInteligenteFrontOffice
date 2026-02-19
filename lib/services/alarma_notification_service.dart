import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Servicio de alarma (sonido 30 s con parada) y notificaciones locales
/// para recordar al usuario cuando termina un temporizador (incluso con la app cerrada).
class AlarmaNotificationService {
  AlarmaNotificationService._();
  static final AlarmaNotificationService _instance = AlarmaNotificationService._();
  static AlarmaNotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  Timer? _alarmStopTimer;
  bool _initialized = false;

  /// Para que la UI pueda mostrar "Parar alarma" mientras suena.
  final ValueNotifier<bool> alarmaSonandoNotifier = ValueNotifier<bool>(false);

  /// Clave para el temporizador global (modo simplificado).
  static const String keyTimerGlobal = '_global_';

  /// Inicialización (llamar desde main antes de runApp o en initState del primer widget).
  static Future<void> init() async {
    if (_instance._initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: android, iOS: ios);
    await _instance._notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _requestPermissionsIfNeeded();
    _instance._initialized = true;
  }

  static Future<void> _requestPermissionsIfNeeded() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _instance._notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _instance._notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(alert: true, sound: true);
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Opcional: abrir la app o una ruta con payload.
  }

  /// Convierte una clave de temporizador en un id numérico positivo para notificaciones.
  static int _idFromKey(String key) {
    final hash = key.hashCode;
    return hash.isNegative ? (-hash) % 0x7FFFFFFF : hash % 0x7FFFFFFF;
  }

  /// Programa una notificación para cuando termine el temporizador.
  /// [key] identifica el timer (p. ej. [keyTimerGlobal] o "_elabId_pasoIndex").
  /// Si la app está cerrada, se mostrará la notificación con sonido.
  Future<void> programarNotificacionTimer({
    required String key,
    required String titulo,
    required String cuerpo,
    required Duration duracion,
  }) async {
    if (!_initialized) return;
    final id = _idFromKey(key);
    final scheduledDate = tz.TZDateTime.from(
      DateTime.now().add(duracion),
      tz.local,
    );
    const androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Temporizadores',
      channelDescription: 'Avisos de temporizadores de recetas',
      playSound: true,
      enableVibration: true,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.zonedSchedule(
      id,
      titulo,
      cuerpo,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancela la notificación programada para esta clave.
  Future<void> cancelarNotificacionTimer(String key) async {
    if (!_initialized) return;
    final id = _idFromKey(key);
    await _notifications.cancel(id);
  }

  /// Reproduce la alarma hasta 30 segundos. Se puede parar con [pararAlarma].
  /// [onParado] se llama al parar (por el usuario o al cumplir 30 s).
  Future<void> reproducirAlarma30Segundos({VoidCallback? onParado}) async {
    await pararAlarma();
    try {
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.setSource(AssetSource('sounds/alarm.wav'));
      await _alarmPlayer.resume();
    } catch (_) {
      // Sin asset de sonido: solo notificación/diálogo; no reproducir nada.
      if (onParado != null) onParado();
      return;
    }
    alarmaSonandoNotifier.value = true;
    _alarmStopTimer?.cancel();
    _alarmStopTimer = Timer(const Duration(seconds: 30), () async {
      await pararAlarma();
      onParado?.call();
    });
  }

  /// Para la alarma inmediatamente.
  Future<void> pararAlarma() async {
    _alarmStopTimer?.cancel();
    _alarmStopTimer = null;
    alarmaSonandoNotifier.value = false;
    await _alarmPlayer.stop();
  }

  /// True si la alarma está sonando (para mostrar botón "Parar alarma").
  bool get alarmaSonando => _alarmStopTimer != null;
}
