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

  static FirebaseMessaging? _messaging;

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;
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

  /// يُعاد استدعاؤها بعد كل تسجيل دخول ناجح (راجع AuthService) لضمان تسجيل
  /// توكن الجهاز حتى لو فشلت المحاولة الأولى عند بدء التشغيل بسبب سباق
  /// توقيت مع تحميل رمز الدخول المحفوظ (JWT) — دون هذه الإعادة قد لا يُسجَّل
  /// التوكن أبدًا رغم عمل كل شيء آخر بشكل صحيح.
  static Future<void> registerTokenNow() async {
    final messaging = _messaging ?? FirebaseMessaging.instance;
    await _registerToken(messaging);
  }

  // أخطاء مثل SERVICE_NOT_AVAILABLE من Google Play Services عادة مؤقتة
  // (انقطاع لحظي في الاتصال بين الجهاز وخوادم Google) — إعادة المحاولة بعد
  // فاصل قصير تحلّها غالبًا تلقائيًا دون أي تدخل من المستخدم. فترات الانتظار
  // بين المحاولات (بالثواني):
  static const List<int> _retryDelaysSeconds = [3, 8, 15];

  static Future<void> _registerToken(FirebaseMessaging messaging, {int attempt = 1}) async {
    try {
      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _vapidKey)
          : await messaging.getToken();
      if (token == null) return;
      await ApiClient.instance.post('/device-tokens', {
        'token': token,
        'platform': kIsWeb ? 'web' : 'android',
      });
    } catch (e) {
      final canRetry = attempt <= _retryDelaysSeconds.length;
      if (canRetry) {
        final delay = _retryDelaysSeconds[attempt - 1];
        await Future.delayed(Duration(seconds: delay));
        await _registerToken(messaging, attempt: attempt + 1);
      }
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);
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
