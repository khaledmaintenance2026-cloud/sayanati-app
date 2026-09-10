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

    if (!kIsWeb) {
      await _initLocalNotifications();
    }

    // === تشخيص مؤقت ===
    try {
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      _debugNotify('صلاحية الإشعارات', 'الحالة: ${settings.authorizationStatus}');
    } catch (e) {
      _debugNotify('خطأ في طلب الصلاحية', '$e');
    }
    // === نهاية التشخيص المؤقت ===

    await _registerToken(messaging);
    messaging.onTokenRefresh.listen((_) => _registerToken(messaging));

    FirebaseMessaging.onMessage.listen((message) {
      if (kIsWeb) return;
      final notification = message.notification;
      if (notification == null) return;
      _showLocalNotification(notification.title, notification.body);
    });
  }

  static Future<void> registerTokenNow() async {
    final messaging = _messaging ?? FirebaseMessaging.instance;
    await _registerToken(messaging);
  }

  // أخطاء مثل SERVICE_NOT_AVAILABLE عادة مؤقتة (انقطاع لحظي في الاتصال بين
  // الجهاز وخوادم Google) — إعادة المحاولة بعد فاصل قصير تحلّها غالبًا
  // تلقائيًا دون أي تدخل من المستخدم. فترات الانتظار بين المحاولات (بالثواني):
  static const List<int> _retryDelaysSeconds = [3, 8, 15];

  static Future<void> _registerToken(FirebaseMessaging messaging, {int attempt = 1}) async {
    try {
      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _vapidKey)
          : await messaging.getToken();
      if (token == null) {
        _debugNotify('تشخيص Push', 'getToken() أرجع null');
        return;
      }
      _debugNotify('تشخيص Push', 'تم الحصول على توكن، جاري الإرسال للسيرفر...');
      await ApiClient.instance.post('/device-tokens', {
        'token': token,
        'platform': kIsWeb ? 'web' : 'android',
      });
      _debugNotify(
        'تشخيص Push',
        attempt == 1 ? 'نجح التسجيل بالكامل ✅' : 'نجح التسجيل بالكامل ✅ (بعد إعادة المحاولة رقم $attempt)',
      );
    } catch (e) {
      final canRetry = attempt <= _retryDelaysSeconds.length;
      if (canRetry) {
        final delay = _retryDelaysSeconds[attempt - 1];
        _debugNotify(
          'تشخيص Push',
          'فشلت المحاولة رقم $attempt (سيُعاد المحاولة تلقائيًا بعد $delay ثوانٍ):\n$e',
        );
        await Future.delayed(Duration(seconds: delay));
        await _registerToken(messaging, attempt: attempt + 1);
        return;
      }
      _debugNotify('تشخيص Push - فشل نهائيًا بعد $attempt محاولات', '$e');
    }
  }

  /// === دالة تشخيص مؤقتة — تعرض النتيجة كإشعار محلي فوري لنراها على
  /// الهاتف مباشرة بدل أن تُبتلع بصمت. تُحذف بمجرد حل مشكلة تسجيل التوكن. ===
  static void _debugNotify(String title, String body) {
    if (kIsWeb) return;
    try {
      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'sayanati_debug',
            'تشخيص مؤقت',
            channelDescription: 'إشعارات تشخيص مؤقتة',
            importance: Importance.high,
            priority: Priority.high,
            // مهم: بدون هذا، أندرويد يقتص أي نص طويل إلى سطر واحد فقط في
            // شريط الإشعارات ولا نرى الخطأ كاملاً. مع BigTextStyle، بمجرد
            // سحب شريط الإشعارات للأسفل يظهر النص كاملاً على عدة أسطر مهما
            // كان طويلاً (لا حاجة لأي ضغط أو فتح إضافي).
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: 'تشخيص صيانتي',
            ),
          ),
        ),
      );
    } catch (_) {}
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
