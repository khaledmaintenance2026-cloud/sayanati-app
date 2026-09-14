// التطبيق الفعلي لدعم البصمة/Face ID على متصفح الويب (سفاري وغيره) عبر
// تقنية WebAuthn القياسية — يستدعي الدوال المعرَّفة في web/index.html
// (window.sayanatiWebAuthn...) عبر dart:js_util. هذا الملف يُستخدم فقط على
// الويب (راجع الاستيراد الشرطي في biometric_service.dart).

import 'dart:js_util' as js_util;

Future<bool> webAuthnSupported() async {
  try {
    final result = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(js_util.globalThis, 'sayanatiWebAuthnSupported', []),
    );
    return result == true;
  } catch (_) {
    return false;
  }
}

Future<String?> webAuthnRegister(String userId, String userName) async {
  try {
    final result = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(js_util.globalThis, 'sayanatiWebAuthnRegister', [userId, userName]),
    );
    return result as String?;
  } catch (_) {
    return null;
  }
}

Future<bool> webAuthnAuthenticate(String credentialId) async {
  try {
    final result = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(js_util.globalThis, 'sayanatiWebAuthnAuthenticate', [credentialId]),
    );
    return result == true;
  } catch (_) {
    return false;
  }
}
