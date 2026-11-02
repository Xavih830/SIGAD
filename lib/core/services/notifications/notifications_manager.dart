import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/services/notifications/notifications_manager_stub.dart'
    if (dart.library.html) 'package:sigad/core/services/notifications/notifications_manager_web.dart'
    if (dart.library.io) 'package:sigad/core/services/notifications/notifications_manager_mobile.dart';

class NotificationsManager {
  static Future<void> init() => NotificationsManagerImpl.init();
  
  static Future<void> showWelcomeNotification(String email) => 
      NotificationsManagerImpl.showWelcomeNotification(email);

  static Future<void> schedulePolicy(PolicyModel policy) =>
      NotificationsManagerImpl.schedulePolicy(policy);
      
  static Future<void> schedulePolicyNotifications(Map<String, dynamic> policy) => 
      NotificationsManagerImpl.schedulePolicyNotifications(policy);
      
  static Future<void> cancelPolicyNotifications(String policyNumber) => 
      NotificationsManagerImpl.cancelPolicyNotifications(policyNumber);
      
  static Future<void> rescheduleAllNotifications(List<Map<String, dynamic>> policies) => 
      NotificationsManagerImpl.rescheduleAllNotifications(policies);
}
