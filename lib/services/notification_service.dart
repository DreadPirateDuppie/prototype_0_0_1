import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:developer' as developer;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;

  // Notification IDs
  static const int _locationSharingReminderId = 100;
  static const int _locationSharingDisabledId = 101;

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions for iOS
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    _initialized = true;
    developer.log('NotificationService initialized', name: 'NotificationService');
  }

  static void _onNotificationTap(NotificationResponse response) {
    developer.log('Notification tapped: ${response.id}', name: 'NotificationService');
    // App automatically opens when notification is tapped
    // You can add navigation logic here if needed
  }

  /// Schedule reminder notification 55 minutes after enabling location sharing
  static Future<void> scheduleLocationSharingReminder() async {
    if (!_initialized) await initialize();

    final scheduledTime = DateTime.now().add(const Duration(minutes: 55));

    await _notifications.zonedSchedule(
      _locationSharingReminderId,
      'Location Sharing Reminder',
      'Your location sharing will turn off in 5 minutes. Tap to keep it on.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'location_sharing_channel',
          'Location Sharing',
          channelDescription: 'Notifications for location sharing status',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF00FF41),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    developer.log('Scheduled location sharing reminder for $scheduledTime',
        name: 'NotificationService');
  }

  /// Show immediate notification when location sharing is auto-disabled
  static Future<void> showLocationSharingDisabled() async {
    if (!_initialized) await initialize();

    await _notifications.show(
      _locationSharingDisabledId,
      'Location Sharing Turned Off',
      'For your privacy, location sharing has been automatically disabled after 1 hour.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'location_sharing_channel',
          'Location Sharing',
          channelDescription: 'Notifications for location sharing status',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF00FF41),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    developer.log('Showed location sharing disabled notification',
        name: 'NotificationService');
  }

  /// Cancel location sharing reminder (when manually disabled)
  static Future<void> cancelLocationSharingReminder() async {
    if (!_initialized) await initialize();

    await _notifications.cancel(_locationSharingReminderId);
    developer.log('Cancelled location sharing reminder',
        name: 'NotificationService');
  }

  /// Cancel all location sharing notifications
  static Future<void> cancelAllLocationNotifications() async {
    if (!_initialized) await initialize();

    await _notifications.cancel(_locationSharingReminderId);
    await _notifications.cancel(_locationSharingDisabledId);
    developer.log('Cancelled all location sharing notifications',
        name: 'NotificationService');
  }

  /// Schedule notification 1 minute before battle turn expires
  static Future<void> scheduleBattleTurnExpiryNotification(
      String battleId, DateTime deadline) async {
    if (!_initialized) await initialize();

    // Calculate time 1 minute before deadline
    final scheduledTime = deadline.subtract(const Duration(minutes: 1));
    
    // If time has already passed, don't schedule
    if (scheduledTime.isBefore(DateTime.now())) return;

    // Use hash of battleId for unique notification ID
    final notificationId = battleId.hashCode;

    await _notifications.zonedSchedule(
      notificationId,
      'Battle Turn Expiring!',
      'You have 1 minute left to make your move!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'battle_updates_channel',
          'Battle Updates',
          channelDescription: 'Notifications for battle turns and updates',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF00FF41),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    developer.log('Scheduled battle expiry notification for $scheduledTime',
        name: 'NotificationService');
  }

  /// Cancel battle expiry notification
  static Future<void> cancelBattleNotification(String battleId) async {
    if (!_initialized) await initialize();
    
    final notificationId = battleId.hashCode;
    await _notifications.cancel(notificationId);
    
    developer.log('Cancelled battle notification for $battleId',
        name: 'NotificationService');
  }
}
