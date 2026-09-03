import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance_report.dart';
import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'maintenance_assign_screen.dart';
import 'maintenance_new_report_screen.dart';
import 'maintenance_report_print_screen.dart';
import 'maintenance_reports_screen.dart';
import 'maintenance_task_close_screen.dart';
import 'maintenance_work_order_screen.dart';

class MaintenanceDashboardScreen extends StatefulWidget {
  const MaintenanceDashboardScreen({super.key});

  @override
  State<MaintenanceDashboardScreen> createState() => _MaintenanceDashboardScreenState();
}

class _MaintenanceDashboardScreenState extends State<MaintenanceDashboardScreen> {
  bool _showEmergency = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reports = state.maintenanceReports
        .where((r) => _showEmergency ? r.isEmergency : !r.isEmergency)
        .toList();

    final completedCount = state.maintenanceReports.where((r) => r.status == MaintenanceStatus.completed).length;
    final preventiveCount = state.maintenanceReports.where((r) => !r.isEmergency).length;
    final total = state.maintenanceReports.isEmpty ? 1 : state.maintenanceReports.length;
    final preventiveRatio = ((preventiveCount / total) * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الصيانة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'التقارير',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MaintenanceReportsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    KpiCard(value: '٤٢ د', label: 'متوسط وقت الإصلاح', valueColor: AppColors.maintenance),
                    const SizedBox(width: 10),
                    KpiCard(value: ArabicFormat.number(completedCount), label: 'أعطال هذا الشهر', valueColor: AppColors.maintenance),
                    const SizedBox(width: 10),
                    KpiCard(value: '٪${ArabicFormat.toEasternDigits(preventiveRatio)}', label: 'نسبة الوقائي', valueColor: AppColors.maintenance),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(child: _Segment(label: 'الأعطال الطارئة', selected: _showEmergency, onTap: () => setState(() => _showEmergency = true))),
                      Expanded(child: _Segment(label: 'أعمال وقائية', selected: !_showEmergency, onTap: () => setState(() => _showEmergency = false))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: reports.isEmpty
                      ? const Center(child: Text('لا توجد بلاغات', style: TextStyle(color: AppColors.textMuted)))
                      : ListView.separated(
                          itemCount: reports.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _ReportCard(report: reports[i]),
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              backgroundColor: AppColors.maintenance,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _showEmergency ? const MaintenanceNewReportScreen() : const MaintenanceWorkOrderScreen(),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3)] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            color: selected ? AppColors.maintenance : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final MaintenanceReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final statusInfo = switch (report.status) {
      MaintenanceStatus.pendingAssignment => (
          label: 'بانتظار التعيين',
          color: AppColors.warningText,
          bg: AppColors.warningBg,
        ),
      MaintenanceStatus.inProgress => (
          label: 'قيد التنفيذ',
          color: AppColors.maintenance,
          bg: AppColors.maintenance.withOpacity(0.1),
        ),
      MaintenanceStatus.completed => (
          label: 'مكتمل',
          color: AppColors.successText,
          bg: AppColors.successBg,
        ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (report.status == MaintenanceStatus.pendingAssignment) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => MaintenanceAssignScreen(report: report)));
        } else if (report.status == MaintenanceStatus.inProgress) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => MaintenanceTaskCloseScreen(report: report)));
        } else if (report.status == MaintenanceStatus.completed) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => MaintenanceReportPrintScreen(report: report)));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${report.equipment} — ${report.line}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (report.status == MaintenanceStatus.completed)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.textMuted),
                  ),
                StatusPill(label: statusInfo.label, color: statusInfo.color, background: statusInfo.bg),
              ],
            ),
            const SizedBox(height: 6),
            Text(report.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_timeAgo(report.reportedAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                Text('رفع: ${report.reportedBy}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return 'قبل ${ArabicFormat.number(diff.inDays)} يوم';
    if (diff.inHours >= 1) return 'منذ ${ArabicFormat.number(diff.inHours)} ساعة';
    return 'منذ ${ArabicFormat.number(diff.inMinutes)} دقيقة';
  }
}
