import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// شاشة إلزامية تظهر بعد أول دخول عبر جوجل حين يكون الحساب بلا رقم جوال
/// (جوجل لا يوفّر رقم الجوال أبدًا) — رقم الجوال إلزامي لكل حساب الآن، ولا
/// يمكن تجاوز هذه الشاشة دون إدخاله. راجع AuthStatus.needsPhone في main.dart.
class CompletePhoneScreen extends StatefulWidget {
  const CompletePhoneScreen({super.key});

  @override
  State<CompletePhoneScreen> createState() => _CompletePhoneScreenState();
}

class _CompletePhoneScreenState extends State<CompletePhoneScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _phoneCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    await auth.submitPhone(_phoneCtrl.text.trim());
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
              const Icon(Icons.phone_iphone_outlined, size: 56, color: AppColors.maintenance),
              const SizedBox(height: 16),
              const Text('خطوة أخيرة', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'مرحبًا بك — قبل الاستمرار، أدخل رقم جوالك (إلزامي لكل حساب) ليصلك إشعارات واتساب الموجَّهة لك شخصيًا.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.6),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerRight,
                child: Text('رقم الجوال', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '05xxxxxxxx',
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              if (auth.lastError != null) ...[
                const SizedBox(height: 10),
                Text(auth.lastError!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12.5)),
              ],
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  : PrimaryButton(
                      label: 'متابعة',
                      color: _canSubmit ? AppColors.maintenance : AppColors.textFaint,
                      onPressed: _canSubmit ? _submit : null,
                    ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.read<AuthService>().signOut(),
                  child: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
