import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'leaves_employees_tab.dart';
import 'leaves_settings_screen.dart';
import 'leaves_summary_tab.dart';
import 'leaves_widgets.dart';

/// اسم مصنع الرجال كما يُخزَّن في حقلي production_facility وsafety_facility للمستخدم.
const String kLeavesFacility = 'مصنع الرجال';

/// من يرى قسم «إجازات الموظفين»؟ نفس أدوار «العمل الإضافي» (مدير النظام + مسؤول
/// الصيانة + مسؤول الإنتاج + مسؤول السلامة) لكن القسم خاص بمصنع الرجال: مسؤول
/// الإنتاج أو السلامة المقيَّد بمصنع النساء لا يراه. هذه الدالة تُخفي القسم في
/// الواجهة فقط؛ القيد الملزم فعليًا على السيرفر في routes/leaves.js (LEAVE_ROLES +
/// requireMenFactory) — يجب أن تبقى القاعدتان متطابقتين.
bool canOpenLeaves(AppUser? user) {
  if (user == null) return false;
  final r = user.role;
  if (r == AppRole.admin || r == AppRole.maintenanceManager) return true;
  if (r == AppRole.productionManager) {
    return user.productionFacility == null || user.productionFacility == kLeavesFacility;
  }
  if (r == AppRole.safety) {
    return user.safetyFacility == null || user.safetyFacility == kLeavesFacility;
  }
  return false;
}

/// شاشة «إجازات الموظفين — مصنع الرجال»: تبويبان (الملخص، الموظفون) وزر إعدادات
/// لمدير النظام فقط.
class LeavesHomeScreen extends StatelessWidget {
  const LeavesHomeScreen({super.key});

  void _openSettings(BuildContext context) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const LeavesSettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    final isAdmin = user != null && user.role == AppRole.admin;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إجازات الموظفين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('مصنع الرجال', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          actions: [
            if (isAdmin)
              IconButton(
                tooltip: 'إعدادات الإجازات',
                icon: const Icon(Icons.tune, color: kLeavesColor),
                onPressed: () => _openSettings(context),
              ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            labelColor: kLeavesColor,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: kLeavesColor,
            tabs: [
              Tab(text: 'الملخص'),
              Tab(text: 'الموظفون'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LeavesSummaryTab(),
            LeavesEmployeesTab(),
          ],
        ),
      ),
    );
  }
}
