import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'medication_reminders';
  static const String _channelName = 'Medication Reminders';
  static const String _channelDesc = 'Reminders for your medications';
  static const String _remindersEnabledKey = 'reminders_enabled';

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    tz_data.initializeTimeZones();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  Future<int> scheduleDailyReminder({
    required int id,
    required String medicationName,
    required String dosage,
    required int hour,
    required int minute,
  }) async {
    if (!await areRemindersEnabled()) {
      return id;
    }

    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    final tzScheduledDate = tz.TZDateTime.from(
      scheduledDate.isAfter(now) ? scheduledDate : scheduledDate.add(
        const Duration(days: 1),
      ),
      tz.local,
    );

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: false,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      'Time to take $medicationName',
      'Dosage: $dosage',
      tzScheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    return id;
  }

  Future<void> scheduleForTimes({
    required int baseId,
    required String medicationName,
    required String dosage,
    required List<String> times,
  }) async {
    if (!await areRemindersEnabled()) {
      return;
    }

    for (int i = 0; i < times.length; i++) {
      final parts = times[i].split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;

        await scheduleDailyReminder(
          id: baseId + i,
          medicationName: medicationName,
          dosage: dosage,
          hour: hour,
          minute: minute,
        );
      }
    }
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelForTimes({
    required int baseId,
    required int count,
  }) async {
    for (int i = 0; i < count; i++) {
      await _plugin.cancel(baseId + i);
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_remindersEnabledKey) ?? true;
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersEnabledKey, enabled);

    if (!enabled) {
      await cancelAll();
    }
  }
}
