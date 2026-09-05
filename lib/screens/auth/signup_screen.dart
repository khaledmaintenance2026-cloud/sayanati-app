import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty && _emailCtrl.text.trim().isNotEmpty && _passCtrl.text.length >= 6;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    await auth.signUp(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text, phone: _phoneCtrl.text.trim());
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: const ScreenTopBar(title: 'إنشاء حساب جديد'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  const InfoNote(
                    text: 'بعد إنشاء الحساب سيراجع مدير النظام طلبك ويحدّد صلاحيتك (صيانة / إنتاج / سلامة) قبل أن تتمكن من استخدام التطبيق.',
                    color: AppColors.maintenance,
                    icon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('الاسم الكامل'),
                  TextField(controller: _nameCtrl, onChanged: (_) => setState(() {}), decoration: _decoration()),
                  const SizedBox(height: 14),
                  const _FieldLabel('البريد الإلكتروني'),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    decoration: _decoration(hint: 'name@example.com'),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('رقم الجوال (اختياري)'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    decoration: _decoration(hint: '05xxxxxxxx'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'يُستخدم لإرسال إشعارات واتساب موجَّهة لك شخصيًا (مثل نتيجة تصريح سلامة)، يمكنك إضافته لاحقًا أيضًا.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('كلمة المرور (٦ أحرف على الأقل)'),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    onChanged: (_) => setState(() {}),
                    decoration: _decoration(hint: '••••••••').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (auth.lastError != null) ...[
                    const SizedBox(height: 10),
                    Text(auth.lastError!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                : PrimaryButton(
                    label: 'إنشاء الحساب',
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

InputDecoration _decoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
  );
}
