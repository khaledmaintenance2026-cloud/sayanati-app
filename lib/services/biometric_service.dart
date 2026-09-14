import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة الدخول بالبصمة — طبقة "قفل" إضافية فوق جلسة الدخول المحفوظة أصلًا
/// (راجع ApiClient/AuthService)، وليست بديلاً عن الحساب نفسه: البصمة لا
/// تُرسَل للسيرفر ولا يعرفها إطلاقًا، هي فقط تفتح جلسة موجودة بالفعل على
/// هذا الجهاز تحديدًا بدل كتابة كلمة المرور في كل مرة يُفتح فيها التطبيق.
///
/// متاحة على تطبيق أندرويد فقط — لا يوجد دعم بصمة حقيقي على الويب، لذلك
/// [isDeviceSupported] تُرجع false مباشرة على الويب دون أي محاولة اتصال
/// بمكتبة local_auth (راجع kIsWeb أدناه).
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const _enabledPrefKey = 'sayanati_biometric_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  /// هل يدعم هذا الجهاز بصمة (أو أي قفل بيومتري آخر) وله بصمة مسجَّلة عليه
  /// فعليًا؟ نتحقق من الاثنين معًا — جهاز بحساس بصمة لكن بلا أي بصمة مسجَّلة
  /// لا فائدة من عرض الخيار له أصلًا.
  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledPrefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPrefKey, value);
  }

  /// يطلب من المستخدم البصمة — مع سماح بالرجوع لرمز/نقش قفل الجهاز كبديل
  /// احتياطي (biometricOnly: false) حتى لا يُحبَس المستخدم خارج التطبيق لو
  /// تعذّرت قراءة البصمة لسبب عارض (إصبع مبلل، حساس متسخ، إلخ). يُرجع true
  /// عند النجاح فقط؛ أي خطأ (رفض المستخدم، عدم توفر بصمة، إلخ) يُعامَل كفشل
  /// بصمت بدل رمي استثناء يوقف الواجهة.
  Future<bool> authenticate({String reason = 'افتح تطبيق صيانتي ببصمتك'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
