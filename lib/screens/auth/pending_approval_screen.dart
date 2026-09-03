import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// تظهر لأي مستخدم أنشأ حسابًا لكن مدير النظام لم يعتمده بعد.
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    await context.read<AuthService>().refreshProfile();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.hourglass_top_outlined, color: AppColors.warningText, size: 38),
              ),
              const SizedBox(height: 22),
              const Text('بانتظار اعتماد الحساب', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'حسابكم (${auth.currentUser?.email ?? ''}) بانتظار موافقة مدير النظام وتحديد صلاحيتكم. حدّثوا الصفحة بعد إبلاغه.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.6),
              ),
              const SizedBox(height: 28),
              _checking
                  ? const CircularProgressIndicator()
                  : PrimaryButton(label: 'تحديث الحالة', color: AppColors.maintenance, icon: Icons.refresh, onPressed: _check),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.read<AuthService>().signOut(),
                child: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
