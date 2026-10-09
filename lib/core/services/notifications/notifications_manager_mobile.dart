import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/services/session_vault.dart';

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
    final welcomedKey = 'welcome_sent_$email';
    final hasBeenWelcomed = await SessionVault.getFlag(welcomedKey, defaultValue: false);

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

    await SessionVault.setFlag(welcomedKey, true);
  }

  static Future<void> schedulePolicy(PolicyModel policy) async {
    final vehicle = policy.vehicle;
    if (vehicle == null) {
      throw StateError('Póliza ${policy.number} sin vehículo asociado para agendar alertas.');
    }
    await schedulePolicyNotifications({
      'numero_poliza': policy.number,
      'placa': vehicle.plate,
      'fecha_fin': policy.endDate.toIso8601String().substring(0, 10),
      'estado': policy.status,
    });
  }

  static Future<void> schedulePolicyNotifications(Map<String, dynamic> policy) async {
    final number = policy['numero_poliza'] as String;
    final plate = policy['placa'] as String;
    final endDateStr = policy['fecha_fin'] as String;
    final status = policy['estado'] as String;

    final endDate = DateTime.parse(endDateStr);

    await cancelPolicyNotifications(number);

    if (status != 'activa' && status != 'por_vencer') {
      return;
    }

    final now = DateTime.now();

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

    final date0 = DateTime(endDate.year, endDate.month, endDate.day, 9, 0);
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
