import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/web_update.dart';

/// رقم هذه النسخة، يضعه بناء GitHub Actions (--dart-define=SAYANATI_BUILD_ID=<الكوميت>).
const String kSayanatiBuildId = String.fromEnvironment('SAYANATI_BUILD_ID');

/// رسالة «يوجد تحديث جديد» (طلب المالك 2026-11-05): على نسخة الويب فقط، يفحص التطبيق
/// كل ٥ دقائق (وعند الرجوع للصفحة) هل نُشرت نسخة أحدث على السيرفر. إن وُجدت يظهر شريط صغير
/// أسفل الشاشة فيه زر «تحديث الآن» يعيد تحميل الصفحة. لا يقاطع العمل ولا يحدّث وحده، حتى لا
/// يضيع ما يكتبه المستخدم في نموذج مفتوح.
class UpdateBanner extends StatefulWidget {
  final Widget child;

  const UpdateBanner({super.key, required this.child});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> with WidgetsBindingObserver {
  static const _interval = Duration(minutes: 5);
  Timer? _timer;
  bool _available = false;
  bool _dismissed = false;

  bool get _enabled => kIsWeb && kSayanatiBuildId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    Future<void>.delayed(const Duration(seconds: 20), _check);
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted || _available) return;
    final latest = await fetchLatestWebBuildId();
    if (!mounted || latest == null || latest.isEmpty) return;
    if (latest != kSayanatiBuildId) setState(() => _available = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_available || _dismissed) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  elevation: 6,
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update_alt, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'يوجد تحديث جديد لتطبيق صيانتي',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _dismissed = true),
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          child: const Text('لاحقًا'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: reloadWebApp,
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          child: const Text('تحديث الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
