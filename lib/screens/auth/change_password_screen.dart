import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _loading = false;
  String? _error;

  // حالة "الدخول بالبصمة" — راجع lib/services/biometric_service.dart.
  bool _biometricLoading = true;
  bool _biometricSupported = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final supported = await BiometricService.instance.isDeviceSupported();
    final enabled = supported && await BiometricService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
      _biometricLoading = false;
    });
  }

    Future<void> _toggleBiometric(bool value) async {
    if (value) {
      bool ok;
      if (kIsWeb) {
        // على الويب: نسجّل بيانات اعتماد WebAuthn جديدة مباشرة (تطلب Face ID/
        // Touch ID أو بصمة الجهاز كجزء من التسجيل نفسه، فلا حاجة لخطوة تأكيد
        // منفصلة كما في أندرويد).
        final user = context.read<AuthService>().currentUser;
        ok = await BiometricService.instance.enableWeb(
          userId: user?.uid ?? DateTime.now().millisecondsSinceEpoch.toString(),
          userName: user?.name ?? user?.email ?? 'مستخدم صيانتي',
        );
      } else {
        // نطلب تأكيد البصمة أولًا قبل التفعيل — حتى لا يُفعِّل المستخدم خيارًا
        // لا تعمل بصمته من أجله أصلًا (حساس معطّل، بصمة غير مسجَّلة بشكل صحيح).
        ok = await BiometricService.instance.authenticate(
          reason: 'أكّد بصمتك لتفعيل الدخول بالبصمة',
        );
        if (ok) await BiometricService.instance.setEnabled(true);
      }
      if (!ok) return;
    } else {
      await BiometricService.instance.setEnabled(false);
    }
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'تم تفعيل الدخول بالبصمة' : 'تم إيقاف الدخول بالبصمة')),
    );
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _currentCtrl.text.isNotEmpty && _newCtrl.text.length >= 6 && _newCtrl.text == _confirmCtrl.text.trim();

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await context.read<AuthService>().changePassword(_currentCtrl.text, _newCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
      );
    } else {
      setState(() => _error = context.read<AuthService>().lastError ?? 'تعذّر تغيير كلمة المرور');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mismatched = _confirmCtrl.text.isNotEmpty && _newCtrl.text != _confirmCtrl.text;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'الحساب والأمان'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ListView(
          children: [
            const SizedBox(height: 6),
            if (!_biometricLoading && _biometricSupported) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint, color: AppColors.maintenance),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('الدخول بالبصمة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    ),
                    Switch(
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                      activeColor: AppColors.maintenance,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const _FieldLabel('كلمة المرور الحالية'),
            TextField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              onChanged: (_) => setState(() {}),
              decoration: _decoration().copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('كلمة المرور الجديدة (٦ أحرف على الأقل)'),
            TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              onChanged: (_) => setState(() {}),
              decoration: _decoration().copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('تأكيد كلمة المرور الجديدة'),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureNew,
              onChanged: (_) => setState(() {}),
              decoration: _decoration(),
            ),
            if (mismatched) ...[
              const SizedBox(height: 8),
              const Text('كلمتا المرور غير متطابقتين', style: TextStyle(color: Color(0xFFB3261E), fontSize: 12.5)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              InfoNote(text: _error!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
            ],
            const SizedBox(height: 22),
            _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                : PrimaryButton(
                    label: 'حفظ كلمة المرور الجديدة',
                    color: _canSubmit ? AppColors.maintenance : AppColors.textFaint,
                    onPressed: _canSubmit ? _submit : null,
                  ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ),
    );
  }
}

InputDecoration _decoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
  );
}
