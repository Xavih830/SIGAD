class NotificationsManagerImpl {
  static Future<void> init() async {}
  static Future<void> showWelcomeNotification(String email) async {}
  static Future<void> schedulePolicyNotifications(Map<String, dynamic> policy) async {}
  static Future<void> cancelPolicyNotifications(String policyNumber) async {}
  static Future<void> rescheduleAllNotifications(List<Map<String, dynamic>> policies) async {}
}
