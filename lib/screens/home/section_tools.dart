import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_home_screen.dart' show canOpenAdminTab;
import '../leaves/leaves_home_screen.dart' show LeavesHomeScreen, canOpenLeaves, kLeavesFacility;
import '../leaves/leaves_widgets.dart' show kLeavesColor;
import '../maintenance/inventory_dashboard_screen.dart' show InventoryDashboardScreen;
import '../mamoul/mamoul_home_screen.dart' show MamoulHomeScreen, canOpenMamoulMonitor;
import '../mamoul/mamoul_widgets.dart' show kMamoulColor;
import '../overtime/overtime_home_screen.dart' show OvertimeHomeScreen, canOpenOvertimeTab;
import '../overtime/overtime_widgets.dart' show kOvertimeColor;

/// ترتيب الصفحة الرئيسية والشريط السفلي (قرار المالك 2026-10-26): أربعة أقسام فقط —
/// الإنتاج، الصيانة، السلامة، الإدارة — وبقية الشاشات صارت «أدوات» داخل الأقسام:
///
/// • العمل الإضافي: داخل كل قسم.
/// • إجازات الموظفين (مصنع الرجال): داخل الإنتاج، تحت تبويب «مصنع الرجال».
/// • مراقبة المعمول (الأوزان) والمخزون: داخل الصيانة.
///
/// الصلاحيات لم تتغير إطلاقًا (كل أداة تُفحص بنفس دالتها القديمة، والقيد الملزم على
/// السيرفر). وحتى لا يفقد أحد وصوله: إن لم يكن للمستخدم القسم الأصلي للأداة (مثل مسؤول
/// الصيانة الذي لا يرى الإنتاج وله الإجازات) تظهر الأداة في أول قسم يراه.
const String kSectionProduction = 'production';
const String kSectionMaintenance = 'maintenance';
const String kSectionSafety = 'safety';
const String kSectionAdmin = 'admin';

const String kToolLeaves = 'leaves';
const String kToolInventory = 'inventory';
const String kToolMamoul = 'mamoul';
const String kToolOvertime = 'overtime';

/// الأقسام التي يراها المستخدم، بالترتيب المعتمد (إنتاج، صيانة، سلامة، إدارة).
List<String> visibleSections(AppUser? user) {
  final out = <String>[];
  if (user == null) return out;
  final r = user.role;
  if (r == AppRole.admin || isProductionRole(r)) out.add(kSectionProduction);
  // مسؤول المخزون والمصمم «أفراد صيانة» بنطاق مهامهما (راجع isInventoryOnlyRole).
  if (r == AppRole.admin || isMaintenanceRole(r) || isInventoryOnlyRole(r)) out.add(kSectionMaintenance);
  if (r == AppRole.admin || r == AppRole.safety) out.add(kSectionSafety);
  if (canOpenAdminTab(r)) out.add(kSectionAdmin);
  return out;
}

/// هل يحق للمستخدم استعمال الأداة؟ (نفس الدوال القديمة بلا أي تعديل في الصلاحيات.)
bool canUseTool(String tool, AppUser? user) {
  if (user == null) return false;
  final r = user.role;
  if (tool == kToolOvertime) return canOpenOvertimeTab(r);
  if (tool == kToolLeaves) return canOpenLeaves(user);
  if (tool == kToolMamoul) return canOpenMamoulMonitor(user);
  if (tool == kToolInventory) return r == AppRole.admin || isMaintenanceRole(r) || isInventoryOnlyRole(r);
  return false;
}

String toolLabel(String tool) {
  if (tool == kToolLeaves) return 'إجازات الموظفين';
  if (tool == kToolInventory) return 'المخزون';
  if (tool == kToolMamoul) return 'المعمول';
  return 'العمل الإضافي';
}

IconData toolIcon(String tool) {
  if (tool == kToolLeaves) return Icons.beach_access_outlined;
  if (tool == kToolInventory) return Icons.inventory_2_outlined;
  if (tool == kToolMamoul) return Icons.precision_manufacturing_outlined;
  return Icons.more_time_outlined;
}

Color toolColor(String tool) {
  if (tool == kToolLeaves) return kLeavesColor;
  if (tool == kToolInventory) return AppColors.inventory;
  if (tool == kToolMamoul) return kMamoulColor;
  return kOvertimeColor;
}

/// القسم الأصلي لكل أداة (العمل الإضافي في كل الأقسام فلا قسم أصلي له).
String? _homeSectionOf(String tool) {
  if (tool == kToolLeaves) return kSectionProduction;
  if (tool == kToolInventory) return kSectionMaintenance;
  if (tool == kToolMamoul) return kSectionMaintenance;
  return null;
}

/// الأدوات التي تظهر داخل [section] لهذا المستخدم. [facility] = المصنع المعروض حاليًا في
/// قسم الإنتاج (تبويب مصنع الرجال/النساء) ليظهر زر الإجازات تحت «مصنع الرجال» فقط.
List<String> toolsForSection(String section, AppUser? user, {String? facility}) {
  final out = <String>[];
  if (user == null) return out;
  final sections = visibleSections(user);
  if (!sections.contains(section)) return out;

  const ordered = <String>[kToolLeaves, kToolInventory, kToolMamoul];
  for (final tool in ordered) {
    if (!canUseTool(tool, user)) continue;
    final home = _homeSectionOf(tool);
    final hasHome = home != null && sections.contains(home);
    final target = hasHome ? home : sections.first;
    if (target != section) continue;
    // الإجازات داخل الإنتاج تخص مصنع الرجال: لا تظهر تحت تبويب مصنع النساء.
    if (tool == kToolLeaves && hasHome && facility != null && facility != kLeavesFacility) continue;
    out.add(tool);
  }
  // العمل الإضافي في كل قسم.
  if (canUseTool(kToolOvertime, user)) out.add(kToolOvertime);
  return out;
}

/// يفتح شاشة الأداة فوق الشاشة الحالية (بزر رجوع تلقائي). تُستعمل من شريط الأدوات ومن
/// الضغط على الإشعارات (مثل إشعار المخزون).
void openSectionTool(BuildContext context, String tool) {
  Widget screen;
  if (tool == kToolLeaves) {
    screen = const LeavesHomeScreen();
  } else if (tool == kToolInventory) {
    screen = const InventoryDashboardScreen();
  } else if (tool == kToolMamoul) {
    screen = const MamoulHomeScreen();
  } else {
    screen = const OvertimeHomeScreen();
  }
  Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
}

/// صف أزرار صغيرة أعلى شاشة القسم، يفتح كل زر أداة القسم (العمل الإضافي، الإجازات، المعمول،
/// المخزون حسب القسم وصلاحية المستخدم). لا يظهر شيئًا إن لم تكن له أدوات هنا.
class SectionToolsBar extends StatelessWidget {
  final String section;

  /// المصنع المعروض حاليًا (قسم الإنتاج فقط).
  final String? facility;

  const SectionToolsBar({super.key, required this.section, this.facility});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final tools = toolsForSection(section, user, facility: facility);
    if (tools.isEmpty) return const SizedBox.shrink();

    final chips = <Widget>[];
    for (final tool in tools) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 8));
      chips.add(_ToolChip(tool: tool, onTap: () => openSectionTool(context, tool)));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final String tool;
  final VoidCallback onTap;

  const _ToolChip({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = toolColor(tool);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
              child: Icon(toolIcon(tool), size: 17, color: color),
            ),
            const SizedBox(width: 8),
            Text(toolLabel(tool), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
