import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Handles push notifications for the app
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _currentToken;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('User granted notification permission');

        // Initialize local notifications for Android
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

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );

        // Get FCM token
        await _getToken();

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages (when app is in background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

        // Check if app was opened from a notification
        final initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationOpened(initialMessage);
        }

        _initialized = true;
        debugPrint('Notification service initialized');
      } else {
        debugPrint('User declined notification permission');
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Get FCM token and save to database
  Future<void> _getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _saveTokenToDatabase(token);
        debugPrint('FCM Token: $token');
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Save device token to Supabase
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No user logged in, cannot save device token');
        return;
      }

      final userBarangayId = user.userMetadata?['user_barangay_id'] as String?;
      if (userBarangayId == null) {
        debugPrint('⚠️ User has no barangay_id, skipping token save');
        debugPrint('   User ID: ${user.id}');
        debugPrint('   User metadata: ${user.userMetadata}');
        debugPrint('   Please set a barangay in Profile → Settings');
        return;
      }

      debugPrint('💾 Saving device token for user: ${user.id}, barangay: $userBarangayId');

      // Upsert device token (update if exists, insert if new)
      await _client.from('user_devices').upsert({
        'user_id': user.id,
        'device_token': token,
        'barangay_id': userBarangayId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_token');

      debugPrint('✅ Device token saved to database successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving device token: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
  }

  /// Remove device token when user logs out
  Future<void> removeToken() async {
    try {
      if (_currentToken != null) {
        final user = _client.auth.currentUser;
        if (user != null) {
          await _client
              .from('user_devices')
              .delete()
              .eq('user_id', user.id)
              .eq('device_token', _currentToken!);
        }
        _currentToken = null;
      }
    } catch (e) {
      debugPrint('Error removing device token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');

    // Show local notification
    final notification = message.notification;
    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'New Report',
        body: notification.body ?? 'A new report has been submitted in your barangay',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification when app is opened from notification
  void _handleNotificationOpened(RemoteMessage message) {
    debugPrint('Notification opened: ${message.messageId}');
    // You can navigate to a specific screen here if needed
    // For example: Navigator.pushNamed(context, '/report/${message.data['report_id']}');
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle navigation here if needed
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'safezone_reports',
      'Report Notifications',
      channelDescription: 'Notifications for new reports in your barangay',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Get current FCM token (for testing/debugging)
  Future<String?> getCurrentToken() async {
    if (!_initialized) {
      await initialize();
    }
    if (_currentToken == null) {
      await _getToken();
    }
    return _currentToken;
  }

  /// Force re-initialize (useful when user updates profile)
  Future<void> reinitialize() async {
    _initialized = false;
    _currentToken = null;
    await initialize();
  }

  /// Send a test notification to the current device
  Future<void> sendTestNotification() async {
    try {
      await _showLocalNotification(
        title: 'Test Notification',
        body: 'This is a test notification from SafeZone PH',
        payload: 'test',
      );
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      rethrow;
    }
  }

  /// Send notification to all users in a barangay
  /// This should be called from a Supabase Edge Function or database trigger
  /// For now, we'll create a helper that can be called from the backend
  static Future<void> notifyBarangayUsers({
    required String barangayId,
    required String reportType,
    String? reportId,
  }) async {
    // This function should be called from a Supabase Edge Function
    // or database trigger after a report is created
    // The actual FCM sending should happen server-side for security
    debugPrint('Notification requested for barangay: $barangayId, type: $reportType');
  }
}

