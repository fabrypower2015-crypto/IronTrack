import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Gestore promemoria allenamento offline basato su notifiche locali Android.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    } catch (_) {
      // Mantiene il fuso orario di fallback se non disponibile
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Richiede il permesso POST_NOTIFICATIONS su Android 13+.
  Future<bool> requestPermission() async {
    await init();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return false;
    final granted = await androidImpl.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Pianifica promemoria settimanali nei giorni configurati nelle schede.
  Future<void> scheduleWorkoutReminders({
    required bool enabled,
    required List<int> weekdays, // 1 = Lun ... 7 = Dom
    required int hour,
    required int minute,
    required Map<int, String> routineNameByWeekday,
  }) async {
    await init();
    await _plugin.cancelAll();
    if (!enabled || weekdays.isEmpty) return;

    final uniqueDays = weekdays.toSet().toList()..sort();
    for (final day in uniqueDays) {
      final scheduled = _nextInstanceOfWeekday(day, hour, minute);
      final routineTitle = routineNameByWeekday[day];
      final body = routineTitle != null
          ? 'Oggi è il giorno di "$routineTitle". Pronto a battere un record?'
          : 'È l\'ora del tuo allenamento in palestra. Spingi al massimo!';

      const androidDetails = AndroidNotificationDetails(
        'irontrack_workout_reminders',
        'Promemoria Allenamenti',
        channelDescription: 'Notifiche programmate per i giorni di palestra.',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _plugin.zonedSchedule(
        100 + day,
        'IronTrack — Giorno di allenamento',
        body,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Invia una notifica istantanea quando termina il timer di recupero.
  Future<void> showRestCompletedNotification() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'irontrack_rest_timer',
      'Timer di Recupero',
      channelDescription: 'Avviso di fine recupero tra le serie.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      999,
      'Recupero terminato!',
      'Torna sotto il bilanciere per la prossima serie.',
      const NotificationDetails(android: androidDetails),
    );
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}