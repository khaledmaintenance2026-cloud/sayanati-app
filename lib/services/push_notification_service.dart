import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

const String _vapidKey =
    'BLNdeutpejJ2Vp5Q8iDgnjCxMmzQRn4QTYBTJs0TrCwtgwYc33kwUHUBKNXAbyCiOdcVjyait0BGhsodzJjRBKQ';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  PushNotificationService._();

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    if (!kIsWeb) {
      await _initLocalNotifications();
    }

    await _registerToken(messaging);
    messaging.onTokenRefresh.listen((_) => _registerToken(messaging));

    FirebaseMessaging.onMessage.listen((message) {
      if (kIsWeb) return;
      final notification = message.notification;
      if (notification == null) return;
      _showLocalNotification(notification.title, notification.body);
    });
  }

  static Future<void> _registerToken(FirebaseMessaging messaging) async {
    try {
      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _vapidKey)
          : await messaging.getToken();
      if (token == null) return;
      await ApiClient.instance.post('/device-tokens', {
        'token': token,
        'platform': kIsWeb ? 'web' : 'android',
      });
    } catch (_) {}
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

    const channel = AndroidNotificationChannel(
      'sayanati_default',
      'إشعارات صيانتي',
      description: 'إشعارات النظام العامة (بلاغات، أوامر عمل، تصاريح سلامة)',
      importance: Importance.high,
      playSound: true,
    );
             await _localNotifications
        .resolvePlatformSpecificImplementation
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _showLocalNotification(String? title, String? body) {
    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title ?? 'صيانتي',
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sayanati_default',
          'إشعارات صيانتي',
          channelDescription:
              'إشعارات النظام العامة (بلاغات، أوامر عمل، تصاريح سلامة)',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  }
}
