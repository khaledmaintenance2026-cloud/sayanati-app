// نسخة بديلة (Stub) تُستخدم في كل المنصات ما عدا الويب — حتى يبقى الكود
// قابلاً للترجمة على أندرويد (dart:js_util غير متاح إلا على الويب). راجع
// web_biometric_web.dart للتطبيق الفعلي على المتصفح.

Future<bool> webAuthnSupported() async => false;

Future<String?> webAuthnRegister(String userId, String userName) async => null;

Future<bool> webAuthnAuthenticate(String credentialId) async => false;
