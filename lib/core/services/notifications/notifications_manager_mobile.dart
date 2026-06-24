import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../hive_helper.dart';

class NotificationsManagerImpl {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> showWelcomeNotification(String email) async {
    final box = HiveHelper.sessionBox;
    final welcomedKey = 'welcome_sent_$email';
    final hasBeenWelcomed = box.get(welcomedKey, defaultValue: false);

    if (hasBeenWelcomed) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'welcome_channel',
      'Bienvenida',
      channelDescription: 'Mensaje de bienvenida al iniciar sesión por primera vez',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: email.hashCode,
      title: 'Bienvenido a SIGAD',
      body: 'Consulta tus pólizas vehiculares, talleres autorizados y números de asistencia desde un solo lugar.',
      notificationDetails: notificationDetails,
    );

    await box.put(welcomedKey, true);
  }

  static Future<void> schedulePolicyNotifications(Map<String, dynamic> policy) async {
    final number = policy['number'] as String;
    final plate = policy['plate'] as String;
    final endDateStr = policy['endDate'] as String;

    DateTime endDate;
    try {
      endDate = DateTime.parse(endDateStr);
    } catch (_) {
      return;
    }

    await cancelPolicyNotifications(number);

    if (policy['status'] != 'activa' || policy['isDeleted'] == true) {
      return;
    }

    final now = DateTime.now();

    // 1. 30 Days before
    final date30 = endDate.subtract(const Duration(days: 30));
    if (date30.isAfter(now)) {
      await _schedule(
        id: number.hashCode + 30,
        title: 'Tu póliza vehicular vence pronto',
        body: 'La póliza $number del vehículo con placa $plate vence el $endDateStr. Contáctanos para renovarla.',
        scheduledDate: date30,
        payload: number,
      );
    }

    // 2. 15 Days before
    final date15 = endDate.subtract(const Duration(days: 15));
    if (date15.isAfter(now)) {
      await _schedule(
        id: number.hashCode + 15,
        title: 'Renueva tu seguro vehicular',
        body: 'Quedan 15 días para que venza la póliza $number del vehículo $plate.',
        scheduledDate: date15,
        payload: number,
      );
    }

    // 3. 7 Days before
    final date7 = endDate.subtract(const Duration(days: 7));
    if (date7.isAfter(now)) {
      await _schedule(
        id: number.hashCode + 7,
        title: 'Tu póliza vence en 7 días',
        body: 'La cobertura del vehículo $plate termina el $endDateStr.',
        scheduledDate: date7,
        payload: number,
      );
    }

    // 4. Expiration Day
    final date0 = DateTime(endDate.year, endDate.month, endDate.day, 9, 0); // 9:00 AM on expiry day
    if (date0.isAfter(now)) {
      await _schedule(
        id: number.hashCode + 0,
        title: 'Póliza vencida',
        body: 'La póliza $number del vehículo $plate ha vencido hoy. Comunícate urgentemente con RJ Seguros.',
        scheduledDate: date0,
        payload: number,
      );
    }
  }

  static Future<void> cancelPolicyNotifications(String policyNumber) async {
    final baseId = policyNumber.hashCode;
    await _notificationsPlugin.cancel(id: baseId + 30);
    await _notificationsPlugin.cancel(id: baseId + 15);
    await _notificationsPlugin.cancel(id: baseId + 7);
    await _notificationsPlugin.cancel(id: baseId + 0);
  }

  static Future<void> rescheduleAllNotifications(List<Map<String, dynamic>> policies) async {
    for (var policy in policies) {
      await schedulePolicyNotifications(policy);
    }
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'policy_expiry_channel',
      'Vencimientos',
      channelDescription: 'Recordatorios de vencimiento de pólizas vehiculares',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }
}
