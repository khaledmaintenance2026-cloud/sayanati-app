import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// استعادة كلمة المرور لمن نسيها (فني أو غيره) — خطوتان في شاشة واحدة:
///  ١) إدخال رقم الجوال → يصل رمز من ٦ أرقام على واتساب الحساب.
///  ٢) إدخال الرمز + كلمة مرور جديدة → ترجع الشاشة بالمُعرِّف إلى شاشة الدخول.
/// لو لم يصل الرمز أو لم يكن للحساب رقم جوال، يعيّن مسؤول الصيانة كلمة مرور
/// مؤقتة من لوحة الإدارة (راجع زر "كلمة مرور مؤقتة" في بطاقة المستخدم).
class ForgotPasswordScreen extends StatefulWidget {
  final String initialIdentifier;
  const ForgotPasswordScreen({super.key, this.initialIdentifier = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _idCtrl;
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _obscure = true;
  String? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _canSend => _idCtrl.text.trim().isNotEmpty;
  bool get _canReset =>
      _codeCtrl.text.trim().length == 6 && isPasswordStrongEnough(_passCtrl.text) && _passCtrl.text == _confirmCtrl.text;

  Future<void> _sendCode() async {
    if (!_canSend) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await context.read<AuthService>().requestPasswordReset(_idCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) {
        _codeSent = true;
        _info = res.message;
        _codeCtrl.clear();
      } else {
        _error = res.message;
      }
    });
  }

  Future<void> _reset() async {
    if (!_canReset) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await context.read<AuthService>().resetPasswordWithCode(_idCtrl.text.trim(), _codeCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (res.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور — سجّل الدخول بها الآن')),
      );
      Navigator.of(context).pop(_idCtrl.text.trim());
    } else {
      setState(() {
        _loading = false;
        _error = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mismatched = _confirmCtrl.text.isNotEmpty && _passCtrl.text != _confirmCtrl.text;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'استعادة كلمة المرور'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: ListView(
          children: [
            if (!_codeSent) ...[
              const InfoNote(
                text: 'أدخل رقم جوالك المسجّل وسنرسل لك رمزًا من ٦ أرقام على واتساب لتعيين كلمة مرور جديدة.',
                color: AppColors.maintenance,
                icon: Icons.chat_outlined,
              ),
              const SizedBox(height: 20),
              const _FieldLabel('رقم الجوال'),
              TextField(
                controller: _idCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: _decoration(hint: '05xxxxxxxx'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InfoNote(text: _error!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
              ],
              const SizedBox(height: 22),
              _loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  : PrimaryButton(
                      label: 'إرسال الرمز على واتساب',
                      color: _canSend ? AppColors.maintenance : AppColors.textFaint,
                      onPressed: _canSend ? _sendCode : null,
                    ),
              const SizedBox(height: 14),
              const Text(
                'لا يصلك الرمز أو نسيت رقمك؟ اطلب من مسؤول الصيانة أن يعيّن لك كلمة مرور مؤقتة.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
              ),
            ] else ...[
              InfoNote(text: _info ?? 'تم إرسال الرمز', color: AppColors.successText, icon: Icons.mark_chat_read_outlined),
              const SizedBox(height: 20),
              const _FieldLabel('الرمز (٦ أرقام)'),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                onChanged: (_) => setState(() {}),
                decoration: _decoration(hint: '······').copyWith(counterText: ''),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('كلمة المرور الجديدة (٨ أحرف على الأقل، فيها حرف ورقم)'),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                onChanged: (_) => setState(() {}),
                decoration: _decoration().copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('تأكيد كلمة المرور الجديدة'),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure,
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
                      label: 'تغيير كلمة المرور',
                      color: _canReset ? AppColors.maintenance : AppColors.textFaint,
                      onPressed: _canReset ? _reset : null,
                    ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _sendCode,
                child: const Text('لم يصل الرمز؟ أعد الإرسال', style: TextStyle(color: AppColors.maintenance, fontWeight: FontWeight.w600)),
              ),
            ],
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
