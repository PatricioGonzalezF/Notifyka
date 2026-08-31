import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/note.dart';

/// Notificaciones locales y recordatorios agendados
/// (`flutter_local_notifications` + `timezone`).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'notify_reminders';
  static const String _channelName = 'Recordatorios';
  static const String _channelDesc = 'Recordatorios de notas de voz';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Usamos UTC como zona "local" de la base de datos de timezone: como los
    // recordatorios se agendan por instante absoluto (TZDateTime.from conserva
    // el momento exacto), la hora de disparo es correcta sin depender de un
    // plugin extra para resolver el nombre de la zona del dispositivo.
    tz.setLocalLocation(tz.getLocation('UTC'));

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
      ),
    );

    _initialized = true;
  }

  /// Pide los permisos de notificaciones (Android 13+) y de alarmas exactas.
  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Agenda (o reagenda) el recordatorio de una nota.
  Future<void> scheduleReminder(Note note) async {
    final DateTime? when = note.reminderDate;
    if (when == null || note.id == null) return;
    if (!when.isAfter(DateTime.now())) return;

    await _plugin.zonedSchedule(
      note.notificationId,
      note.title.isEmpty ? 'Recordatorio' : note.title,
      _buildBody(note.content),
      tz.TZDateTime.from(when, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(Note note) => _plugin.cancel(note.notificationId);

  Future<void> cancelAll() => _plugin.cancelAll();

  String _buildBody(String content) {
    final String text = content.trim().replaceAll('\n', ' ');
    if (text.isEmpty) return 'Tienes una nota pendiente';
    return text.length > 120 ? '${text.substring(0, 120)}...' : text;
  }
}
