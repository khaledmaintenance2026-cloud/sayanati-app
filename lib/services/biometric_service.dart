import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_biometric_stub.dart' if (dart.library.html) 'web_biometric_web.dart' as webauthn;

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();
  static const _enabledPrefKey = 'sayanati_biometric_enabled';
  static const _webCredentialIdKey = 'sayanati_biometric_web_credential_id';
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) {
      try {
        return await webauthn.webAuthnSupported();
      } catch (_) {
        return false;
      }
    }
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

  /// يُستخدم مباشرة على أندرويد (بعد التحقق بالبصمة) أو لإيقاف الميزة على أي
  /// منصة. على الويب لتفعيلها استخدم [enableWeb] بدلاً منها مباشرة.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!value) {
      await prefs.remove(_webCredentialIdKey);
    }
    await prefs.setBool(_enabledPrefKey, value);
  }

  /// يسجّل بصمة/Face ID جديدة عبر WebAuthn على متصفح الويب (سفاري وغيره)
  /// ويخزّن معرّف بيانات الاعتماد محليًا — بديل تفعيل مباشر لـ[setEnabled]
  /// على الويب تحديدًا، لأن التفعيل هناك يحتاج تسجيل بيانات اعتماد فعلية أولًا.
  Future<bool> enableWeb({required String userId, required String userName}) async {
    if (!kIsWeb) return false;
    try {
      final credentialId = await webauthn.webAuthnRegister(userId, userName);
      if (credentialId == null || credentialId.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_webCredentialIdKey, credentialId);
      await prefs.setBool(_enabledPrefKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'افتح تطبيق صيانتي ببصمتك'}) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final credentialId = prefs.getString(_webCredentialIdKey);
        if (credentialId == null || credentialId.isEmpty) return false;
        return await webauthn.webAuthnAuthenticate(credentialId);
      } catch (_) {
        return false;
      }
    }
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
