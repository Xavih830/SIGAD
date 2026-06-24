import 'notifications_manager_stub.dart'
    if (dart.library.html) 'notifications_manager_web.dart'
    if (dart.library.io) 'notifications_manager_mobile.dart';

class NotificationsManager {
  static Future<void> init() => NotificationsManagerImpl.init();
  
  static Future<void> showWelcomeNotification(String email) => 
      NotificationsManagerImpl.showWelcomeNotification(email);
      
  static Future<void> schedulePolicyNotifications(Map<String, dynamic> policy) => 
      NotificationsManagerImpl.schedulePolicyNotifications(policy);
      
  static Future<void> cancelPolicyNotifications(String policyNumber) => 
      NotificationsManagerImpl.cancelPolicyNotifications(policyNumber);
      
  static Future<void> rescheduleAllNotifications(List<Map<String, dynamic>> policies) => 
      NotificationsManagerImpl.rescheduleAllNotifications(policies);
}
