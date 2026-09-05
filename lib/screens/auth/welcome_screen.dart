import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// شاشة ترحيب متحركة تظهر مرة واحدة فقط عند فتح التطبيق (قبل شاشة تسجيل
/// الدخول)، بدل فيديو خارجي — شعار الماس للعطور + اسم النظام، مع الانتقال
/// تلقائيًا بعد ثوانٍ أو فور ضغط "متابعة".
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const WelcomeScreen({super.key, required this.onContinue});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _visible = false;
  bool _continued = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _visible = true);
    });
    // ينتقل تلقائيًا بعد ٤ ثوانٍ إن لم يضغط المستخدم "متابعة" بنفسه.
    Future.delayed(const Duration(seconds: 4), _continue);
  }

  void _continue() {
    if (_continued || !mounted) return;
    _continued = true;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.maintenance,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: _visible ? 1 : 0.6,
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _visible ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    child: Container(
                      width: 130,
                      height: 130,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 900),
                  child: const Text('صيانتي', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 1100),
                  child: const Text(
                    'نظام إدارة الصيانة والإنتاج والسلامة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 46),
                AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 1300),
                  child: TextButton(
                    onPressed: _continue,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.16),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('متابعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_left, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
