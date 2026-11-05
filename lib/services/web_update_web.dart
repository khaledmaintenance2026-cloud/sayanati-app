import 'dart:convert';
import 'dart:html' as html;

/// يقرأ رقم آخر نسخة ويب منشورة على السيرفر (app_build.json يكتبه بناء GitHub Actions).
/// ?t= يمنع أي تخزين مؤقت. يرجع null عند أي خطأ (بلا رسالة للمستخدم).
Future<String?> fetchLatestWebBuildId() async {
  try {
    final text = await html.HttpRequest.getString('app_build.json?t=${DateTime.now().millisecondsSinceEpoch}');
    final data = jsonDecode(text);
    if (data is Map && data['build'] is String) return data['build'] as String;
  } catch (_) {}
  return null;
}

/// إعادة تحميل الصفحة: index.html لا يُخزَّن، فيجلب الملفات الجديدة برقمها الجديد.
void reloadWebApp() => html.window.location.reload();
