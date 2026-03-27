import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'consultation_api_service.dart';

/// Recordatorios locales ~1 h antes de la cita (1.7). Sin FCM.
class AppointmentReminderService {
  AppointmentReminderService._();
  static final AppointmentReminderService instance = AppointmentReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const Duration _lead = Duration(hours: 1);

  static int _notificationId(String consultationId) => consultationId.hashCode & 0x7fffffff;

  Future<void> init() async {
    if (kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      if (name.startsWith('Etc/GMT') || name == 'UTC') {
        tz.setLocalLocation(tz.getLocation('America/Bogota'));
      } else {
        tz.setLocalLocation(tz.getLocation(name));
      }
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'appointment_reminders',
        'Recordatorios de citas',
        description: 'Aviso antes de tu consulta programada',
        importance: Importance.high,
      ),
    );
    if (Platform.isAndroid) {
      await android?.requestNotificationsPermission();
    }

    _ready = true;
  }

  Future<void> syncFromConsultations(List<ConsultationSummaryDto> items) async {
    if (kIsWeb || !_ready) return;

    await _plugin.cancelAll();

    final now = DateTime.now();
    for (final c in items) {
      final raw = c.scheduledAt;
      if (raw == null || raw.isEmpty) continue;

      DateTime start;
      try {
        start = DateTime.parse(raw);
      } catch (_) {
        continue;
      }

      final startLocal = start.toLocal();
      final fireAt = startLocal.subtract(_lead);
      if (!fireAt.isAfter(now)) continue;

      final tzWhen = tz.TZDateTime.from(fireAt, tz.local);
      final label = (c.specialistLabel != null && c.specialistLabel!.trim().isNotEmpty)
          ? c.specialistLabel!.trim()
          : c.specialty.trim();
      final title = 'Cita médica pronto';
      final body = label.isNotEmpty
          ? 'Tu consulta con $label es a las ${_fmtHm(startLocal)}.'
          : 'Tienes una consulta a las ${_fmtHm(startLocal)}.';

      await _plugin.zonedSchedule(
        _notificationId(c.id),
        title,
        body,
        tzWhen,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'appointment_reminders',
            'Recordatorios de citas',
            channelDescription: 'Aviso antes de tu consulta programada',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  String _fmtHm(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
