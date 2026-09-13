import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Create notification channel (Android 8+)
    const androidChannel = AndroidNotificationChannel(
      'kompli_compliance',
      'Compliance Reminders',
      description: 'Deadline reminders for your statutory obligations',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
    debugPrint('NotificationService: Initialized successfully');
  }

  Future<void> scheduleComplianceReminders() async {
    if (!_initialized) await init();

    // Cancel any previous scheduled notifications
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    // ── CAC Annual Returns — June 30 each year (7 days warning) ──
    final cacDeadline = _nextOccurrence(month: 6, day: 30);
    final cacReminder = cacDeadline.subtract(const Duration(days: 7));
    if (cacReminder.isAfter(now)) {
      await _scheduleNotification(
        id: 1,
        title: '⚠️ CAC Annual Returns Due Soon',
        body: 'Your CAC Annual Returns are due in 7 days (June 30). File now to avoid ₦3,000/month penalties.',
        scheduledDate: cacReminder,
      );
    }

    // ── FIRS VAT — 21st of every month (5 days warning) ──
    for (int monthOffset = 0; monthOffset < 12; monthOffset++) {
      final vatDeadline = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + monthOffset > 12
            ? (now.month + monthOffset) % 12
            : now.month + monthOffset,
        21,
      );
      final vatReminder = vatDeadline.subtract(const Duration(days: 5));
      if (vatReminder.isAfter(now)) {
        await _scheduleNotification(
          id: 10 + monthOffset,
          title: '📋 FIRS VAT Return Due in 5 Days',
          body: 'Monthly VAT return is due on the 21st. Avoid ₦50,000 first-month penalty.',
          scheduledDate: vatReminder,
        );
        break; // Only schedule next upcoming one
      }
    }

    // ── PENCOM Pension — End of every month (5 days warning) ──
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final pensionDeadline = tz.TZDateTime(
        tz.local, lastDayOfMonth.year, lastDayOfMonth.month, lastDayOfMonth.day);
    final pensionReminder = pensionDeadline.subtract(const Duration(days: 5));
    if (pensionReminder.isAfter(now)) {
      await _scheduleNotification(
        id: 3,
        title: '👥 PENCOM Pension Contribution Due',
        body: 'Monthly pension contributions are due at end of month. Avoid 2% payroll penalty.',
        scheduledDate: pensionReminder,
      );
    }

    // ── ITF — April 1 each year (14 days warning) ──
    final itfDeadline = _nextOccurrence(month: 4, day: 1);
    final itfReminder = itfDeadline.subtract(const Duration(days: 14));
    if (itfReminder.isAfter(now)) {
      await _scheduleNotification(
        id: 4,
        title: '🎓 ITF Training Contribution Due Soon',
        body: 'ITF contribution is due April 1. Pay 1% of annual payroll to avoid legal action.',
        scheduledDate: itfReminder,
      );
    }

    debugPrint('NotificationService: Compliance reminders scheduled.');
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'kompli_compliance',
      'Compliance Reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(0, title, body, details);
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'kompli_compliance',
      'Compliance Reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Get the next occurrence of a specific month/day from today.
  tz.TZDateTime _nextOccurrence({required int month, required int day}) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(tz.local, now.year, month, day);
    if (candidate.isBefore(now)) {
      candidate = tz.TZDateTime(tz.local, now.year + 1, month, day);
    }
    return candidate;
  }
}
