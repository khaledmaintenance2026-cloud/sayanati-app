// فحص وجود نسخة ويب أحدث من المفتوحة حاليًا (راجع lib/widgets/update_banner.dart).
// على أندرويد لا يعمل شيء (stub)، وعلى الويب يقرأ app_build.json من السيرفر.
export 'web_update_stub.dart' if (dart.library.html) 'web_update_web.dart';
