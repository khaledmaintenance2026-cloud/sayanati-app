import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'maintenance_dashboard_screen.dart';

/// الأعمال المنجزة — منفصلة عن لوحة العمل اليومية (maintenance_dashboard_screen)
/// حتى لا تتراكم فيها للأبد. من هنا يمكن فتح تقرير PDF لأي عمل منجز، أو حذفه
/// نهائيًا بعد التأكد من عدم الحاجة إليه (البيانات محلية على هذا الجهاز فقط).
class MaintenanceCompletedScreen extends StatelessWidget {
  const MaintenanceCompletedScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, String reportId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نهائي', style: TextStyle(fontSize: 15)),
        content: Text('سيُحذف "$title" نهائيًا من سجل الصيانة على هذا الجهاز. لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB3261E), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppState>().deleteMaintenanceReport(reportId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العمل من السجل')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final completed = state.completedMaintenanceReports;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'الأعمال المنجزة'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: completed.isEmpty
            ? const Center(child: Text('لا توجد أعمال منجزة بعد', style: TextStyle(color: AppColors.textMuted)))
            : ListView.separated(
                itemCount: completed.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = completed[i];
                  return MaintenanceReportCard(
                    report: r,
                    onDelete: () => _confirmDelete(context, r.id, '${r.equipment} — ${r.line}'),
                  );
                },
              ),
      ),
    );
  }
}
