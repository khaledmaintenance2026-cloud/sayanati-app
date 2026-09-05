import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.maintenance.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              const Text('صيانتي', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('تسجيل الدخول للمتابعة', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
              const SizedBox(height: 32),
              if (!kApiBaseUrlConfigured) const ServerConfigWarning(),
              const _FieldLabel('البريد الإلكتروني'),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(hint: 'name@example.com'),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('كلمة المرور'),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
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
              const SizedBox(height: 20),
              _loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  : PrimaryButton(label: 'تسجيل الدخول', color: AppColors.maintenance, onPressed: _submit),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                  child: const Text('ليس لديك حساب؟ إنشاء حساب جديد', style: TextStyle(color: AppColors.maintenance, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
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

/// تنبيه يظهر فقط إذا لم يُعدَّل lib/services/constants.dart بعد برابط سيرفر
/// صيانتي الفعلي — يوضّح للمستخدم سبب فشل تسجيل الدخول بدل ترك خطأ غامض.
class ServerConfigWarning extends StatelessWidget {
  const ServerConfigWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: InfoNote(
        text: 'لم يُضبط رابط سيرفر صيانتي بعد — عدّلوا kApiBaseUrl في lib/services/constants.dart ليطابق سيرفركم أولاً.',
        color: Color(0xFFB45309),
        icon: Icons.warning_amber_outlined,
      ),
    );
  }
}
