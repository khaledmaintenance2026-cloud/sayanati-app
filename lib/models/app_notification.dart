/// إشعار داخل التطبيق — يصل من /api/notifications، ويظهر فقط للمستخدم
/// المعنيّ به تحديدًا (فني عُيِّن له بلاغ، من رفع بلاغًا عند إنجازه، قسم
/// السلامة عند طلب تصريح، مقدّم تصريح عند مراجعته...). بديل خفيف عن إشعارات
/// نظام Push الحقيقية (تلك تحتاج ربط خدمة Firebase منفصلة، غير موجودة بعد).
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? eventType;
  final String? refId;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.eventType,
    this.refId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromApi(Map<String, dynamic> d) => AppNotification(
        id: d['id'].toString(),
        title: (d['title'] as String?) ?? '',
        body: (d['body'] as String?) ?? '',
        eventType: d['event_type'] as String?,
        refId: d['ref_id']?.toString(),
        isRead: (d['is_read'] as bool?) ?? false,
        createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}
